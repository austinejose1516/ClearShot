import AppKit
import ScreenshotXXCore

/// One editor window per capture. Reopening Edit brings back the same document with its edits.
@MainActor
final class EditorSessionStore {
    static let shared = EditorSessionStore()
    private var controllers: [Capture.ID: EditorWindowController] = [:]

    func close(captureID: Capture.ID) {
        controllers.removeValue(forKey: captureID)?.close()
    }

    func open(capture: Capture) {
        let controller = controllers[capture.id] ?? EditorWindowController(capture: capture)
        controllers[capture.id] = controller
        NSApp.activate()
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }
}
