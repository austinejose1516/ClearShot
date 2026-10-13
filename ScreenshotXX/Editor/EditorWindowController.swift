import AppKit
import ScreenshotXXCore
import SwiftUI

final class EditorWindowController: NSWindowController, NSWindowDelegate {
    let editorDocument: EditorDocument
    let state = EditorState()
    private let onWindowClosed: () -> Void

    init(capture: Capture, onFinished: @escaping () -> Void, onWindowClosed: @escaping () -> Void) {
        editorDocument = EditorDocument(baseImage: capture.image)
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
        window.contentViewController = NSHostingController(rootView: EditorView(
            document: editorDocument,
            state: state,
            actions: window.actions,
            fileURL: capture.fileURL,
            onSaved: { [weak window] url in
                window?.title = url.lastPathComponent
                window?.isDocumentEdited = false
                onFinished()
            },
            onCopied: onFinished,
            onEdited: { [weak window] edited in window?.isDocumentEdited = edited }))
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    func windowWillClose(_ notification: Notification) {
        onWindowClosed()
    }
}
