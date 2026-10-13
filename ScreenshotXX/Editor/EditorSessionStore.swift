import AppKit
import ScreenshotXXCore

/// One editor window per capture. Closing the window keeps unsaved edits while the capture's card can
/// still reopen them; otherwise the editor (image and undo history) is freed. See `EditorLifetime`.
@MainActor
final class EditorSessionStore {
    static let shared = EditorSessionStore()
    private var controllers: [Capture.ID: EditorWindowController] = [:]
    private var cardsGone: Set<Capture.ID> = []
    /// Called after Save or Copy, once the editor window is closed (the card closes too).
    var onFinished: ((Capture.ID) -> Void)?

    func open(capture: Capture) {
        let controller = controllers[capture.id] ?? EditorWindowController(
            capture: capture,
            onFinished: { [weak self] in self?.didFinish(captureID: capture.id) },
            onWindowClosed: { [weak self] in self?.releaseIfDone(capture.id, windowIsOpen: false) })
        controllers[capture.id] = controller
        controller.window.map(WindowPresenter.show)
    }

    /// Closes and frees the editor now (Save, Copy, Move to Trash).
    func close(captureID: Capture.ID) {
        cardsGone.remove(captureID)
        controllers.removeValue(forKey: captureID)?.close()
    }

    func cardDismissed(_ captureID: Capture.ID) {
        guard let controller = controllers[captureID] else { return }
        cardsGone.insert(captureID)
        let window = controller.window
        releaseIfDone(captureID, windowIsOpen: window?.isVisible == true || window?.isMiniaturized == true)
    }

    private func didFinish(captureID: Capture.ID) {
        close(captureID: captureID)
        onFinished?(captureID)
    }

    private func releaseIfDone(_ captureID: Capture.ID, windowIsOpen: Bool) {
        guard let controller = controllers[captureID],
              EditorLifetime.shouldRelease(windowIsOpen: windowIsOpen,
                                           hasUnsavedEdits: controller.editorDocument.canUndo,
                                           cardIsOpen: !cardsGone.contains(captureID)) else { return }
        controllers.removeValue(forKey: captureID)
        cardsGone.remove(captureID)
    }
}
