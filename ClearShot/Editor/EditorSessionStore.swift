import AppKit
import ClearShotCore

/// One editor window per capture. Closing the window keeps the drawings (saved or not) while the capture's
/// card can still reopen them; otherwise the editor (image and undo history) is freed. See `EditorLifetime`.
@MainActor
final class EditorSessionStore {
    static let shared = EditorSessionStore()
    private var controllers: [Capture.ID: EditorWindowController] = [:]
    private var cardsGone: Set<Capture.ID> = []
    /// After Done, once the editor has shrunk into its card: the card takes the new picture and saves it.
    var onDone: ((Capture.ID, CGImage) -> Void)?

    func open(capture: Capture, settings: AppSettings) {
        let controller = controllers[capture.id] ?? EditorWindowController(
            capture: capture,
            settings: settings,
            onDone: { [weak self] image in
                self?.goBack(capture.id, picture: image) { image.map { self?.onDone?(capture.id, $0) } }
            },
            onCloseRequest: { [weak self] in self?.goBack(capture.id, picture: nil) {} },
            onWindowClosed: { [weak self] in
                CardTransition.cards?.bringBack(capture.id)   // however it closed, the card comes back
                self?.releaseIfDone(capture.id, windowIsOpen: false)
            })
        controllers[capture.id] = controller
        controller.window.map { CardTransition.open($0, for: capture.id) { controller.pictureFrameOnScreen() } }
    }

    /// Closes and frees the editor now (Move to Trash).
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

    /// Done or the close button: the editor shrinks back into its card and closes. The drawings stay editable
    /// while the card is open.
    private func goBack(_ captureID: Capture.ID, picture: CGImage?, then done: @escaping @MainActor () -> Void) {
        guard let controller = controllers[captureID], let window = controller.window else { return done() }
        CardTransition.close(window, for: captureID, picture: picture, from: controller.pictureFrameOnScreen()) {
            controller.close()
            done()
        }
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
