import AppKit
import ClearShotCore
import SwiftUI
import UniformTypeIdentifiers

/// One editor window. Every command, from a key or a toolbar button, ends up in `perform`.
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    let session: EditorSession
    private let viewState = EditorViewState()
    private let settings: AppSettings
    private let fileURL: URL?
    private let onFinished: () -> Void
    private let onWindowClosed: () -> Void

    var editorDocument: EditorDocument { session.document }

    init(capture: Capture, settings: AppSettings, onFinished: @escaping () -> Void, onWindowClosed: @escaping () -> Void) {
        session = EditorSession(document: EditorDocument(baseImage: capture.editorImage, frame: capture.editorFrame))
        self.settings = settings
        fileURL = capture.fileURL
        self.onFinished = onFinished
        self.onWindowClosed = onWindowClosed
        let window = EditorWindow(
            contentRect: NSRect(x: 0, y: 0, width: EditorView.defaultSize.width, height: EditorView.defaultSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = capture.fileURL?.lastPathComponent ?? "Screenshot"
        window.minSize = EditorView.minimumSize
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.onCommand = { [weak self] in self?.perform($0) }
        let host = NSHostingController(rootView: EditorView(
            session: session,
            viewState: viewState,
            onCommand: { [weak self] in self?.perform($0) },
            onShare: { [weak self] in self?.share(from: $0) },
            onEdited: { [weak window] edited in window?.isDocumentEdited = edited })
            .themed(settings))
        // A window with a content view controller takes its minimum size from that controller, so SwiftUI's
        // minimum (the toolbar's width) must be reported; the preferred size is not, so a small screenshot never
        // shrinks the window.
        host.sizingOptions = .minSize
        window.contentViewController = host
        // Attaching a content view controller resizes the window to that view's own frame, so set the size after.
        window.setContentSize(EditorView.defaultSize)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    func windowWillClose(_ notification: Notification) {
        onWindowClosed()
    }

    func perform(_ command: EditorCommand) {
        switch command {
        case .undo: session.document.undo()
        case .redo: session.document.redo()
        case .delete: session.deleteSelection()
        case .selectAll: session.selectAll()
        case .cancel: session.cancel()
        case .confirm: session.applyCrop()
        case .zoomIn: viewState.zoom(by: 1.25)
        case .zoomOut: viewState.zoom(by: 1 / 1.25)
        case .copy: copyToClipboard()
        case .save: fileURL.map(write(to:)) ?? saveAs()
        case .saveAs: saveAs()
        case .newLine: (window as? EditorWindow)?.insertNewLineInText()
        case .bold: session.apply(.bold(!session.shownValues.bold))
        case .italic: session.apply(.italic(!session.shownValues.italic))
        case .underline: session.apply(.underline(!session.shownValues.underline))
        case .upload: upload()
        }
    }

    /// Sends the result to the cloud bucket and copies the link; then the editor closes, like Copy and Save.
    /// Without a cloud setup it opens Settings → Cloud instead.
    private func upload() {
        guard viewState.uploadProgress == nil else { return }
        guard let uploader = R2Uploader.fromSettings(settings) else {
            UploadService.openCloudSettings()
            return
        }
        guard let image = renderResult() else { return }
        let format = settings.imageFormat
        let viewState = viewState
        viewState.uploadProgress = 0
        Task {
            defer { viewState.uploadProgress = nil }
            do {
                let budget = settings.fileBudget
                let encoded = try await Task.detached { try FileSaver.encode(image, preferring: format, budget: budget) }.value
                try await UploadService.upload(encoded.data, format: encoded.format, with: uploader) { fraction in
                    Task { @MainActor in viewState.uploadProgress = fraction }
                }
                onFinished()
            } catch {
                ErrorPresenter.show(title: "Upload failed", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Output

    private func renderResult() -> CGImage? {
        session.finishTextEditing()
        guard let image = Exporter.render(session.document) else {
            ErrorPresenter.show(title: "Export failed", message: "The image could not be rendered.")
            return nil
        }
        return image
    }

    private func copyToClipboard() {
        guard let image = renderResult() else { return }
        ClipboardService.copy(image)
        Toast.show("Copied")
        onFinished()
    }

    /// The Share menu with the result as a temp PNG. The editor stays open: the menu may be cancelled.
    private func share(from anchor: NSView?) {
        guard let anchor = anchor ?? window?.contentView, let image = renderResult() else { return }
        let budget = settings.fileBudget
        Task {
            do {
                ShareService.share([try await ShareService.temporaryFile(image, budget: budget)], from: anchor)
            } catch {
                ErrorPresenter.show(title: "Could not share", message: error.localizedDescription)
            }
        }
    }

    private func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "ClearShot.png"
        panel.directoryURL = fileURL?.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(to: url)
    }

    /// Encodes off the main thread (the smaller PNG takes a moment), then closes like Copy. When the size
    /// budget turns the result into a JPEG, the file changes its extension and the old one goes.
    private func write(to url: URL) {
        guard let image = renderResult() else { return }
        let preferred = ImageFormat(url: url) ?? .png
        let budget = settings.fileBudget
        Task {
            do {
                let encoded = try await Task.detached { try FileSaver.encode(image, preferring: preferred, budget: budget) }.value
                let target = encoded.format == preferred ? url : url.deletingPathExtension().appendingPathExtension(encoded.format.fileExtension)
                try encoded.data.write(to: target, options: .atomic)
                if target != url { try? FileManager.default.removeItem(at: url) }
                DiagnosticLog.write("editor saved \(image.width)x\(image.height) px, \(encoded.data.count / 1024) KB, to \(target.path(percentEncoded: false))")
                window?.isDocumentEdited = false
                onFinished()
            } catch {
                ErrorPresenter.show(title: "Could not save", message: error.localizedDescription)
            }
        }
    }
}
