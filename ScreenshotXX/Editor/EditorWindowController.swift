import AppKit
import ScreenshotXXCore
import SwiftUI
import UniformTypeIdentifiers

/// One editor window. Every command, from a key or a toolbar button, ends up in `perform`.
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    let session: EditorSession
    private let viewState = EditorViewState()
    private let fileURL: URL?
    private let onFinished: () -> Void
    private let onWindowClosed: () -> Void

    var editorDocument: EditorDocument { session.document }

    init(capture: Capture, onFinished: @escaping () -> Void, onWindowClosed: @escaping () -> Void) {
        session = EditorSession(document: EditorDocument(baseImage: capture.image))
        fileURL = capture.fileURL
        self.onFinished = onFinished
        self.onWindowClosed = onWindowClosed
        let window = EditorWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = capture.fileURL?.lastPathComponent ?? "Screenshot"
        window.minSize = NSSize(width: 1040, height: 600)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.onCommand = { [weak self] in self?.perform($0) }
        window.contentViewController = NSHostingController(rootView: EditorView(
            session: session,
            viewState: viewState,
            onCommand: { [weak self] in self?.perform($0) },
            onEdited: { [weak window] edited in window?.isDocumentEdited = edited }))
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

    private func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "ScreenshotXX.png"
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
