import AppKit
import ScreenshotXXCore

/// One editor window per capture. Reopening Edit brings back the same document with its edits.
@MainActor
final class EditorSessionStore {
    static let shared = EditorSessionStore()
    private var controllers: [Capture.ID: EditorWindowController] = [:]
    /// Called after a successful save, once the editor window is closed (the card closes too).
    var onSaved: ((Capture.ID) -> Void)?

    func didSave(captureID: Capture.ID) {
        close(captureID: captureID)
        onSaved?(captureID)
    }

    func close(captureID: Capture.ID) {
        controllers.removeValue(forKey: captureID)?.close()
    }

    func open(capture: Capture) {
        let controller = controllers[capture.id] ?? EditorWindowController(capture: capture) { [weak self] in
            self?.didSave(captureID: capture.id)
        }
        controllers[capture.id] = controller
        NSApp.activate()
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }
}
