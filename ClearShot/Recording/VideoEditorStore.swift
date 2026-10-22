import AppKit
import ClearShotCore

/// One video editor per recording card, like `EditorSessionStore` for screenshots. Closing the window keeps an
/// unsaved trim or blur boxes while the card can still reopen it; otherwise the editor is freed. See `EditorLifetime`.
@MainActor
final class VideoEditorStore {
    static let shared = VideoEditorStore()
    private var controllers: [Capture.ID: VideoWindowController] = [:]
    private var cardsGone: Set<Capture.ID> = []
    /// After a Save that changed the file, once the editor has shrunk into its card: the card takes the new
    /// length and first frame.
    var onSaved: ((Capture.ID, VideoSaveResult) -> Void)?

    /// Needs the saved file; a card that is still saving has Edit greyed out.
    func open(capture: Capture, settings: AppSettings) {
        guard let fileURL = capture.fileURL, let video = capture.video else { return }
        let controller = controllers[capture.id] ?? VideoWindowController(
            fileURL: fileURL,
            video: video,
            settings: settings,
            onSaved: { [weak self] result in
                // Saved: the editor is freed, so Edit opens the saved file afresh.
                self?.goBack(capture.id, picture: result?.poster) {
                    self?.close(captureID: capture.id)
                    result.map { self?.onSaved?(capture.id, $0) }
                }
            },
            onCloseRequest: { [weak self] in
                self?.goBack(capture.id, picture: nil) { self?.controllers[capture.id]?.close() }
            },
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
        guard let controller = controllers.removeValue(forKey: captureID) else { return }
        controller.release()
        controller.close()
    }

    func cardDismissed(_ captureID: Capture.ID) {
        guard let controller = controllers[captureID] else { return }
        cardsGone.insert(captureID)
        let window = controller.window
        releaseIfDone(captureID, windowIsOpen: window?.isVisible == true || window?.isMiniaturized == true)
    }

    /// Save or the close button: the editor shrinks back into its card, then `done` closes it.
    private func goBack(_ captureID: Capture.ID, picture: CGImage?, then done: @escaping @MainActor () -> Void) {
        guard let controller = controllers[captureID], let window = controller.window else { return done() }
        CardTransition.close(window, for: captureID, picture: picture, from: controller.pictureFrameOnScreen(), then: done)
    }

    private func releaseIfDone(_ captureID: Capture.ID, windowIsOpen: Bool) {
        guard let controller = controllers[captureID],
              EditorLifetime.shouldRelease(windowIsOpen: windowIsOpen,
                                           hasUnsavedEdits: controller.hasUnsavedEdits,
                                           cardIsOpen: !cardsGone.contains(captureID)) else { return }
        controllers.removeValue(forKey: captureID)
        cardsGone.remove(captureID)
        controller.release()
    }
}
