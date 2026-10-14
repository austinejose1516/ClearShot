import KeyboardShortcuts
import ClearShotCore

extension KeyboardShortcuts.Name {
    static let captureArea = Self("captureArea", initial: .init(.a, modifiers: [.control, .shift]))
    static let captureWindow = Self("captureWindow", initial: .init(.w, modifiers: [.control, .shift]))
    static let captureFullScreen = Self("captureFullScreen", initial: .init(.f, modifiers: [.control, .shift]))
    static let recordScreen = Self("recordScreen", initial: .init(.r, modifiers: [.control, .shift]))
    static let scrollingCapture = Self("scrollingCapture", initial: .init(.s, modifiers: [.control, .shift]))
}

final class HotkeyService {
    private let coordinator: CaptureCoordinator
    private let recording: RecordingCoordinator

    init(coordinator: CaptureCoordinator, recording: RecordingCoordinator) {
        self.coordinator = coordinator
        self.recording = recording
    }

    func register() {
        KeyboardShortcuts.onKeyUp(for: .captureArea) { [coordinator] in coordinator.capture(.area) }
        KeyboardShortcuts.onKeyUp(for: .captureWindow) { [coordinator] in coordinator.capture(.window) }
        KeyboardShortcuts.onKeyUp(for: .captureFullScreen) { [coordinator] in coordinator.capture(.fullScreen) }
        KeyboardShortcuts.onKeyUp(for: .scrollingCapture) { [coordinator] in coordinator.capture(.scrolling) }
        // The same key starts an area recording and stops the one running.
        KeyboardShortcuts.onKeyUp(for: .recordScreen) { [recording] in recording.toggle() }
    }
}
