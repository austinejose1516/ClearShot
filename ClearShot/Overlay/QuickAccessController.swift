import AppKit
import ClearShotCore
import SwiftUI

/// Owns the Quick Access cards: one panel per capture (screenshot or recording), newest on the left, per screen.
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
    /// Cards that became an editor: out of the row (the others close the gap) until the editor goes back in.
    private var away: Set<Capture.ID> = []
    /// Pictures an editor finished that still have to go into the card's file (it may not be written yet).
    private var unsavedEdits: [Capture.ID: CGImage] = [:]
    /// Cards whose file is being rewritten right now.
    private var rewriting: Set<Capture.ID> = []
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
        let presentation = CardPresentation(image: capture.image, videoDuration: capture.video?.duration)
        presentation.fileURL = capture.fileURL
        let id = capture.id
        let view = QuickAccessView(
            capture: capture,
            presentation: presentation,
            onEdit: { [weak self] in self?.current(id).map { self?.onEdit?($0) } },
            onCopy: { [weak self] in self?.copy(id) },
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
    /// drag-out come alive (and for a recording, every action).
    func fileWritten(_ id: Capture.ID, at url: URL) {
        setFile(id, url)
        entries.first { $0.capture.id == id }?.presentation.saveProgress = nil
        rewriteIfReady(id, file: url)   // an edit that came before the file was there
    }

    private func setFile(_ id: Capture.ID, _ url: URL?) {
        guard let index = entries.firstIndex(where: { $0.capture.id == id }) else { return }
        entries[index].capture.fileURL = url
        entries[index].presentation.fileURL = url
    }

    /// The screenshot editor is done: the card shows the new picture at once, bounces and says Saved. Its file
    /// is rewritten in the background, after the first save if that is still running. An old upload link is
    /// for the old picture, so it goes.
    func editorDone(_ id: Capture.ID, image: CGImage) {
        guard let index = entries.firstIndex(where: { $0.capture.id == id }) else { return }
        entries[index].capture.edited(image: image)
        refresh(index, image: image)
        unsavedEdits[id] = image
        rewriteIfReady(id, file: entries[index].capture.fileURL)
    }

    /// The video editor saved a trim (it writes the file itself): the new length and first frame.
    func savedVideo(_ id: Capture.ID, duration: Double, poster: CGImage, encoding: VideoEncoding.Settings, at url: URL) {
        guard let index = entries.firstIndex(where: { $0.capture.id == id }) else { return }
        entries[index].capture.saved(videoDuration: duration, poster: poster, encoding: encoding, at: url)
        entries[index].presentation.videoDuration = duration
        entries[index].presentation.fileURL = url
        refresh(index, image: poster)
    }

    private func refresh(_ index: Int, image: CGImage) {
        let presentation = entries[index].presentation
        presentation.image = image
        presentation.uploadedLink = nil
        presentation.savedCount += 1
        scheduleAutoClose(entries[index].capture.id)
    }

    /// Writes the latest edit over the card's file once that file exists. Meanwhile the card has no file, so
    /// Share and Upload use the picture itself and Reveal waits. Runs even when the card has closed.
    private func rewriteIfReady(_ id: Capture.ID, file: URL?) {
        guard let file, !rewriting.contains(id), let image = unsavedEdits.removeValue(forKey: id) else { return }
        rewriting.insert(id)
        setFile(id, nil)
        let budget = settings.fileBudget
        Task {
            let result = await Task.detached { Result { try FileSaver.overwrite(file, with: image, budget: budget) } }.value
            rewriting.remove(id)
            switch result {
            case .success(let url):
                DiagnosticLog.write("edit saved \(image.width)x\(image.height) px to \(url.path(percentEncoded: false))")
                fileWritten(id, at: url)
            case .failure(let error):
                fileWritten(id, at: file)
                ErrorPresenter.show(title: "Could not save the edit", message: error.localizedDescription)
            }
        }
    }

    // MARK: - The card becomes the editor (see CardTransition)

    /// Edit: the card leaves the row. Returns its picture and where the picture was, for it to fly from.
    func sendAway(_ id: Capture.ID) -> (thumbnail: CGRect, image: CGImage)? {
        guard let entry = entries.first(where: { $0.capture.id == id }), !away.contains(id), let frame = plan().frames[id] else {
            return nil
        }
        away.insert(id)
        autoCloseTasks.removeValue(forKey: id)?.cancel()
        hovered.remove(id)
        entry.presentation.isAway = true
        entry.panel.orderOut(nil)
        layout(animated: true)
        let image = entry.presentation.image
        return (QuickAccessLayout.thumbnailRect(imageSize: CGSize(width: image.width, height: image.height), inCard: frame), image)
    }

    /// The editor is about to go back: the card's place opens up again (the card is still hidden). Returns
    /// where a picture of `imageSize` will sit on the card, for it to fly into; nil when the card is gone.
    func makeRoom(for id: Capture.ID, imageSize: CGSize) -> CGRect? {
        guard entries.contains(where: { $0.capture.id == id }) else { return nil }
        if away.remove(id) != nil { layout(animated: true) }
        return plan().frames[id].map { QuickAccessLayout.thumbnailRect(imageSize: imageSize, inCard: $0) }
    }

    /// What the card shows now.
    func picture(of id: Capture.ID) -> CGImage? {
        entries.first { $0.capture.id == id }?.presentation.image
    }

    /// The editor has landed: the card shows again.
    func bringBack(_ id: Capture.ID) {
        if away.remove(id) != nil { layout(animated: true) }
        guard let entry = entries.first(where: { $0.capture.id == id }) else { return }
        entry.presentation.isAway = false
        entry.panel.orderFrontRegardless()
        scheduleAutoClose(id)
    }

    /// 0…1 while a recording is compressed into its file; nil when done.
    func setSaveProgress(_ id: Capture.ID, _ fraction: Double?) {
        entries.first { $0.capture.id == id }?.presentation.saveProgress = fraction
    }

    func close(id: Capture.ID) {
        dismiss(id: id)
        layout(animated: true)
    }

    /// The capture as it is now, with the file URL once the file exists.
    private func current(_ id: Capture.ID) -> Capture? {
        entries.first { $0.capture.id == id }?.capture
    }

    // MARK: - Copy, share and upload

    /// A screenshot copies its picture; a recording copies its file.
    private func copy(_ id: Capture.ID) {
        guard let capture = current(id) else { return }
        if capture.isVideo {
            capture.fileURL.map(ClipboardService.copy(fileURL:))
        } else {
            ClipboardService.copy(capture.image)
        }
    }

    private func share(_ id: Capture.ID, from anchor: NSView?) {
        guard let anchor, let capture = current(id) else { return }
        if capture.isVideo {
            if let file = capture.fileURL { ShareService.share([file], from: anchor) }
            return
        }
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
        if capture.isVideo {
            uploadVideo(capture, presentation: presentation, with: uploader)
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

    private func uploadVideo(_ capture: Capture, presentation: CardPresentation, with uploader: R2Uploader) {
        guard let file = capture.fileURL else { return }
        presentation.uploadProgress = 0
        Task {
            defer { presentation.uploadProgress = nil }
            do {
                presentation.uploadedLink = try await UploadService.upload(fileURL: file, contentType: "video/mp4", folder: .videos,
                                                                           with: uploader) { fraction in
                    Task { @MainActor in presentation.uploadProgress = fraction }
                }
            } catch {
                ErrorPresenter.show(title: "Upload failed", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Layout

    private func layout(animated: Bool, appearing: Capture.ID? = nil) {
        let (frames, overflow) = plan()
        for entry in entries {
            guard let frame = frames[entry.capture.id] else { continue }
            place(entry.panel, at: frame, animated: animated, appearing: entry.capture.id == appearing)
        }
        overflow.forEach(dismiss(id:))
    }

    /// Where each card in the row goes, per screen (a card that is away takes no place), and the cards there is
    /// no room for.
    private func plan() -> (frames: [Capture.ID: CGRect], overflow: [Capture.ID]) {
        var frames: [Capture.ID: CGRect] = [:]
        var overflow: [Capture.ID] = []
        let inRow = entries.filter { !away.contains($0.capture.id) }
        for (displayID, group) in Dictionary(grouping: inRow, by: { $0.displayID }) {
            // A card whose screen was unplugged moves to the main screen.
            let screen = NSScreen.screens.first { $0.displayID == displayID } ?? NSScreen.main
            guard let visible = screen?.visibleFrame else { continue }
            let slots = QuickAccessLayout.frames(count: group.count, in: visible)
            for (index, entry) in group.enumerated() {
                if index < slots.count { frames[entry.capture.id] = slots[index] } else { overflow.append(entry.capture.id) }
            }
        }
        return (frames, overflow)
    }

    private func place(_ panel: QuickAccessPanel, at cardFrame: CGRect, animated: Bool, appearing: Bool) {
        let margin = QuickAccessLayout.panelMargin
        let frame = cardFrame.insetBy(dx: -margin, dy: -margin)
        if appearing {
            // The SwiftUI card plays its own spring entrance; the panel just needs to be there.
            panel.setFrame(frame, display: false)
            panel.orderFrontRegardless()
        } else if animated, panel.isVisible {
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
        guard !away.contains(id) else { return }   // never while it is an editor
        let seconds = settings.cardAutoCloseSeconds
        guard seconds > 0 else { return }
        autoCloseTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.close(id: id)
        }
    }
}
