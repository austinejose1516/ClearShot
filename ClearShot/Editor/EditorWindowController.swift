import AppKit
import ClearShotCore
import SwiftUI

/// One editor window. Every command, from a key or a toolbar button, ends up in `perform`. It writes no file:
/// Done hands the result to the card, which saves it and has Copy, Share and Upload.
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    let session: EditorSession
    private let viewState = EditorViewState()
    private let settings: AppSettings
    /// The result, or nil when nothing was edited (the card and its file stay as they are).
    private let onDone: (CGImage?) -> Void
    /// The close button: the store shrinks the editor back into its card first.
    private let onCloseRequest: () -> Void
    private let onWindowClosed: () -> Void

    var editorDocument: EditorDocument { session.document }

    init(capture: Capture, settings: AppSettings, onDone: @escaping (CGImage?) -> Void,
         onCloseRequest: @escaping () -> Void, onWindowClosed: @escaping () -> Void) {
        session = EditorSession(document: EditorDocument(baseImage: capture.editorImage, frame: capture.editorFrame))
        self.settings = settings
        self.onDone = onDone
        self.onCloseRequest = onCloseRequest
        self.onWindowClosed = onWindowClosed
        let window = EditorWindow(
            contentRect: NSRect(x: 0, y: 0, width: EditorView.defaultSize.width, height: EditorView.defaultSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = capture.fileURL?.lastPathComponent ?? "Screenshot"
        window.minSize = EditorView.minimumSize
        window.isReleasedWhenClosed = false
        // Opens on the Space you are on, also over an app in full screen, like the card it grew from.
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        super.init(window: window)
        window.delegate = self
        window.onCommand = { [weak self] in self?.perform($0) }
        let host = NSHostingController(rootView: EditorView(
            session: session,
            viewState: viewState,
            onCommand: { [weak self] in self?.perform($0) },
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

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onCloseRequest()
        return false   // the store closes it once it is back in the card
    }

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
        case .done: done()
        case .newLine: (window as? EditorWindow)?.insertNewLineInText()
        case .bold: session.apply(.bold(!session.shownValues.bold))
        case .italic: session.apply(.italic(!session.shownValues.italic))
        case .underline: session.apply(.underline(!session.shownValues.underline))
        }
    }

    /// Where the picture is on screen at the editor's zoom: the canvas centred in the space under the toolbar
    /// (left of the frame panel when it is open). The card animation flies the picture to and from here.
    func pictureFrameOnScreen() -> CGRect? {
        guard let window else { return nil }
        let content = window.contentLayoutRect
        let panel = viewState.showsFramePanel ? FramePanelView.width + 1 : 0
        let viewport = CGRect(x: content.minX, y: content.minY,
                              width: content.width - panel, height: content.height - EditorToolbar.height - 1)
        var zoom = viewState.canvasZoom
        zoom.canvasSize = session.document.layout.canvasSize
        return window.convertToScreen(zoom.shownRect(in: viewport))
    }

    // MARK: - Output

    /// The result goes back to the card (which saves it); the drawings stay editable here.
    private func done() {
        session.finishTextEditing()
        guard session.document.canUndo else { return onDone(nil) }
        guard let image = Exporter.render(session.document) else {
            ErrorPresenter.show(title: "Export failed", message: "The image could not be rendered.")
            return
        }
        window?.isDocumentEdited = false
        onDone(image)
    }
}
