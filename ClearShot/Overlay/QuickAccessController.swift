import AppKit
import ClearShotCore
import SwiftUI

/// Owns the Quick Access cards: one panel per capture, newest on the left, per screen.
@MainActor
final class QuickAccessController {
    private struct Entry {
        let id: Capture.ID
        let panel: QuickAccessPanel
        let presentation: CardPresentation
        let displayID: CGDirectDisplayID?
    }

    private let settings: AppSettings
    private var entries: [Entry] = []          // newest first
    private var hovered: Set<Capture.ID> = []
    private var autoCloseTasks: [Capture.ID: Task<Void, Never>] = [:]
    private var screenObserver: NSObjectProtocol?

    var onEdit: ((Capture) -> Void)?
    var onDelete: ((Capture) -> Void)?
    /// Every way a card leaves (close, auto-close, overflow, delete, after Save).
    var onDismissed: ((Capture.ID) -> Void)?

    init(settings: AppSettings) {
        self.settings = settings
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.layout(animated: false) }
        }
    }

    func show(_ capture: Capture, on screen: NSScreen?) {
        let margin = QuickAccessLayout.panelMargin
        let panel = QuickAccessPanel(frame: CGRect(origin: .zero, size: QuickAccessLayout.cardSize).insetBy(dx: -margin, dy: -margin))
        let presentation = CardPresentation()
        let view = QuickAccessView(
            capture: capture,
            presentation: presentation,
            onEdit: { [weak self] in self?.onEdit?(capture) },
            onCopy: { ClipboardService.copy(capture.image) },
            onShare: { [settings] anchor in
                guard let anchor else { return }
                Task {
                    do {
                        // The saved file when it is there (it is written moments after the card appears), else a temp PNG.
                        let file = capture.fileURL.flatMap { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) ? $0 : nil }
                        let item: URL
                        if let file {
                            item = file
                        } else {
                            item = try await ShareService.temporaryPNG(capture.image, smaller: settings.smallerPNG, date: capture.createdAt)
                        }
                        ShareService.share([item], from: anchor)
                    } catch {
                        ErrorPresenter.show(title: "Could not share", message: error.localizedDescription)
                    }
                }
            },
            onUpload: { [weak self] in self?.upload(capture, presentation: presentation) },
            onReveal: {
                if let url = capture.fileURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            },
            onDelete: { [weak self] in
                self?.onDelete?(capture)
                self?.close(id: capture.id)
            },
            onClose: { [weak self] in self?.close(id: capture.id) },
            onHoverChange: { [weak self] inside in self?.hoverChanged(capture.id, inside: inside) })
        panel.contentView = FirstMouseHostingView(rootView: view.themed(settings))
        entries.insert(Entry(id: capture.id, panel: panel, presentation: presentation,
                             displayID: (screen ?? NSScreen.main)?.displayID), at: 0)
        layout(animated: true, appearing: capture.id)
        scheduleAutoClose(capture.id)
    }

    func close(id: Capture.ID) {
        dismiss(id: id)
        layout(animated: true)
    }

    // MARK: - Upload

    /// The saved file's bytes when it is on disk, else the image encoded in the chosen format. The card stays.
    private func upload(_ capture: Capture, presentation: CardPresentation) {
        guard presentation.uploadProgress == nil else { return }
        guard let uploader = R2Uploader.fromSettings(settings) else {
            UploadService.openCloudSettings()
            return
        }
        let format = capture.fileURL.flatMap(ImageFormat.init(url:)) ?? settings.imageFormat
        let smaller = settings.smallerPNG
        presentation.uploadProgress = 0
        Task {
            defer { presentation.uploadProgress = nil }
            do {
                let data = try await Task.detached { () throws -> Data in
                    if let url = capture.fileURL, let saved = try? Data(contentsOf: url) { return saved }
                    return try FileSaver.encode(capture.image, format: format, smaller: smaller)
                }.value
                presentation.uploadedLink = try await UploadService.upload(data, format: format, with: uploader) { fraction in
                    Task { @MainActor in presentation.uploadProgress = fraction }
                }
            } catch {
                ErrorPresenter.show(title: "Upload failed", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Layout

    private func layout(animated: Bool, appearing: Capture.ID? = nil) {
        var overflow: [Capture.ID] = []
        let groups = Dictionary(grouping: entries, by: { $0.displayID })
        for (displayID, group) in groups {
            // A card whose screen was unplugged moves to the main screen.
            let screen = NSScreen.screens.first { $0.displayID == displayID } ?? NSScreen.main
            guard let visible = screen?.visibleFrame else { continue }
            let frames = QuickAccessLayout.frames(count: group.count, in: visible)
            for (index, entry) in group.enumerated() {
                guard index < frames.count else { overflow.append(entry.id); continue }
                place(entry.panel, at: frames[index], animated: animated, appearing: entry.id == appearing)
            }
        }
        overflow.forEach(dismiss(id:))
    }

    private func place(_ panel: QuickAccessPanel, at cardFrame: CGRect, animated: Bool, appearing: Bool) {
        let margin = QuickAccessLayout.panelMargin
        let frame = cardFrame.insetBy(dx: -margin, dy: -margin)
        if appearing {
            // The SwiftUI card plays its own spring entrance; the panel just needs to be there.
            panel.setFrame(frame, display: false)
            panel.orderFrontRegardless()
        } else if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.32
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private func dismiss(id: Capture.ID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let entry = entries.remove(at: index)
        autoCloseTasks.removeValue(forKey: id)?.cancel()
        hovered.remove(id)
        entry.presentation.isDismissing = true
        onDismissed?(id)
        Task {
            try? await Task.sleep(for: .milliseconds(260))
            entry.panel.orderOut(nil)
            entry.panel.contentView = nil
        }
    }

    // MARK: - Auto-close

    private func hoverChanged(_ id: Capture.ID, inside: Bool) {
        if inside {
            hovered.insert(id)
            autoCloseTasks.removeValue(forKey: id)?.cancel()
        } else {
            hovered.remove(id)
            scheduleAutoClose(id)
        }
    }

    private func scheduleAutoClose(_ id: Capture.ID) {
        autoCloseTasks[id]?.cancel()
        let seconds = settings.cardAutoCloseSeconds
        guard seconds > 0 else { return }
        autoCloseTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.close(id: id)
        }
    }
}
