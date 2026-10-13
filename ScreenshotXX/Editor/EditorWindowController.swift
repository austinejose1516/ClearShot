import AppKit
import ScreenshotXXCore
import SwiftUI

final class EditorWindowController: NSWindowController {
    let editorDocument: EditorDocument
    let state = EditorState()
    private(set) var fileURL: URL?

    init(capture: Capture) {
        editorDocument = EditorDocument(baseImage: capture.image)
        fileURL = capture.fileURL
        let window = EditorWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = capture.fileURL?.lastPathComponent ?? "Screenshot"
        window.minSize = NSSize(width: 1040, height: 600)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentViewController = NSHostingController(rootView: EditorView(
            document: editorDocument,
            state: state,
            actions: window.actions,
            fileURL: fileURL,
            onSaved: { [weak self, weak window] url in
                self?.fileURL = url
                window?.title = url.lastPathComponent
                window?.isDocumentEdited = false
            },
            onEdited: { [weak window] edited in window?.isDocumentEdited = edited }))
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }
}
