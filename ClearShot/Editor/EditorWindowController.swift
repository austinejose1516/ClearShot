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
        // The window keeps its size whatever the image is; a small screenshot must not shrink it under the toolbar.
        host.sizingOptions = []
        window.contentViewController = host
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
        guard !viewState.isUploading else { return }
        guard let uploader = R2Uploader.fromSettings(settings) else {
            UploadService.openCloudSettings()
            return
        }
        guard let image = renderResult() else { return }
        let format = settings.imageFormat
        viewState.isUploading = true
        Task {
            defer { viewState.isUploading = false }
            do {
                let data = try await Task.detached { try FileSaver.encode(image, format: format) }.value
                try await UploadService.upload(data, format: format, with: uploader)
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
        onFinished()
    }

    /// The Share menu with the result as a temp PNG. The editor stays open: the menu may be cancelled.
    private func share(from anchor: NSView?) {
        guard let anchor = anchor ?? window?.contentView, let image = renderResult() else { return }
        do {
            ShareService.share([try ShareService.temporaryPNG(image)], from: anchor)
        } catch {
            ErrorPresenter.show(title: "Could not share", message: error.localizedDescription)
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

    private func write(to url: URL) {
        guard let image = renderResult() else { return }
        do {
            try FileSaver.overwrite(image, format: ImageFormat(url: url) ?? .png, at: url)
            DiagnosticLog.write("editor saved \(image.width)x\(image.height) px to \(url.path(percentEncoded: false))")
            window?.isDocumentEdited = false
            onFinished()
        } catch {
            ErrorPresenter.show(title: "Could not save", message: error.localizedDescription)
        }
    }
}
