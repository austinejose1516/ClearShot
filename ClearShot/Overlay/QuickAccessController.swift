import AppKit
import ClearShotCore
import SwiftUI

/// Owns the Quick Access cards: one panel per capture, newest on the left, per screen.
@MainActor
final class QuickAccessController {
    private struct Entry {
        var capture: Capture
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

    /// Shows the card right away; the file usually does not exist yet (see `fileWritten`).
    func show(_ capture: Capture, on screen: NSScreen?) {
        let margin = QuickAccessLayout.panelMargin
        let panel = QuickAccessPanel(frame: CGRect(origin: .zero, size: QuickAccessLayout.cardSize).insetBy(dx: -margin, dy: -margin))
        let presentation = CardPresentation()
        presentation.fileURL = capture.fileURL
        let id = capture.id
        let view = QuickAccessView(
            capture: capture,
            presentation: presentation,
            onEdit: { [weak self] in self?.current(id).map { self?.onEdit?($0) } },
            onCopy: { ClipboardService.copy(capture.image) },
            onShare: { [weak self] anchor in self?.share(id, from: anchor) },
            onUpload: { [weak self] in self?.upload(id) },
            onReveal: { [weak self] in
                if let url = self?.current(id)?.fileURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            },
            onDelete: { [weak self] in
                self?.current(id).map { self?.onDelete?($0) }
                self?.close(id: id)
            },
            onClose: { [weak self] in self?.close(id: id) },
            onHoverChange: { [weak self] inside in self?.hoverChanged(id, inside: inside) })
        panel.contentView = FirstMouseHostingView(rootView: view.themed(settings))
        entries.insert(Entry(capture: capture, panel: panel, presentation: presentation,
                             displayID: (screen ?? NSScreen.main)?.displayID), at: 0)
        layout(animated: true, appearing: id)
        scheduleAutoClose(id)
    }

    /// The file is on disk now (its type may differ from the capture's first guess): Reveal, Trash and the
    /// drag-out come alive.
    func fileWritten(_ id: Capture.ID, at url: URL) {
        guard let index = entries.firstIndex(where: { $0.capture.id == id }) else { return }
        entries[index].capture.fileURL = url
        entries[index].presentation.fileURL = url
    }

    func close(id: Capture.ID) {
        dismiss(id: id)
        layout(animated: true)
    }

    /// The capture as it is now, with the file URL once the file exists.
    private func current(_ id: Capture.ID) -> Capture? {
        entries.first { $0.capture.id == id }?.capture
    }

    // MARK: - Share and upload

    private func share(_ id: Capture.ID, from anchor: NSView?) {
        guard let anchor, let capture = current(id) else { return }
        let budget = settings.fileBudget
        Task {
            do {
                // The saved file when it is there (it is written moments after the card appears), else a temp file.
                let file = capture.fileURL.flatMap { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) ? $0 : nil }
                let item: URL
                if let file {
                    item = file
                } else {
                    item = try await ShareService.temporaryFile(capture.image, budget: budget, date: capture.createdAt)
                }
                ShareService.share([item], from: anchor)
            } catch {
                ErrorPresenter.show(title: "Could not share", message: error.localizedDescription)
            }
        }
    }

    /// The saved file's bytes when it is on disk, else the image encoded like a save would be. The card stays.
    private func upload(_ id: Capture.ID) {
        guard let entry = entries.first(where: { $0.capture.id == id }) else { return }
        let capture = entry.capture, presentation = entry.presentation
        guard presentation.uploadProgress == nil else { return }
        guard let uploader = R2Uploader.fromSettings(settings) else {
            UploadService.openCloudSettings()
            return
        }
        let preferred = settings.imageFormat
        let budget = settings.fileBudget
        presentation.uploadProgress = 0
        Task {
            defer { presentation.uploadProgress = nil }
            do {
                let (data, format) = try await Task.detached { () throws -> (Data, ImageFormat) in
                    if let url = capture.fileURL, let saved = try? Data(contentsOf: url), let format = ImageFormat(url: url) {
                        return (saved, format)
                    }
                    let encoded = try FileSaver.encode(capture.image, preferring: preferred, budget: budget)
                    return (encoded.data, encoded.format)
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
                guard index < frames.count else { overflow.append(entry.capture.id); continue }
                place(entry.panel, at: frames[index], animated: animated, appearing: entry.capture.id == appearing)
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
        guard let index = entries.firstIndex(where: { $0.capture.id == id }) else { return }
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
