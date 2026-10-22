import KeyboardShortcuts
import ClearShotCore

/// One pattern: the letter is the kind (A/W/F for screenshots, S for scrolling, R for recording); for scrolling
/// and recording, ⌥ means Window and ⌘ means Full Screen. The first five names are older than the pattern.
extension KeyboardShortcuts.Name {
    static let captureArea = Self("captureArea", initial: .init(.a, modifiers: [.control, .shift]))
    static let captureWindow = Self("captureWindow", initial: .init(.w, modifiers: [.control, .shift]))
    static let captureFullScreen = Self("captureFullScreen", initial: .init(.f, modifiers: [.control, .shift]))
    static let scrollingCapture = Self("scrollingCapture", initial: .init(.s, modifiers: [.control, .shift]))
    static let scrollingWindow = Self("scrollingWindow", initial: .init(.s, modifiers: [.control, .option, .shift]))
    static let scrollingFullScreen = Self("scrollingFullScreen", initial: .init(.s, modifiers: [.control, .shift, .command]))
    static let recordScreen = Self("recordScreen", initial: .init(.r, modifiers: [.control, .shift]))
    static let recordWindow = Self("recordWindow", initial: .init(.r, modifiers: [.control, .option, .shift]))
    static let recordFullScreen = Self("recordFullScreen", initial: .init(.r, modifiers: [.control, .shift, .command]))
    static let pauseRecording = Self("pauseRecording", initial: .init(.p, modifiers: [.control, .shift]))
    /// The capture bar. No key until the user sets one; "Use the macOS shortcuts" gives it ⇧⌘5, like the Mac's own bar.
    static let captureBar = Self("captureBar")
}

final class HotkeyService {
    private let coordinator: CaptureCoordinator
    private let recording: RecordingCoordinator
    private let scrolling: ScrollingCoordinator
    private let launcher: CaptureLauncher

    init(coordinator: CaptureCoordinator, recording: RecordingCoordinator, scrolling: ScrollingCoordinator, launcher: CaptureLauncher) {
        self.coordinator = coordinator
        self.recording = recording
        self.scrolling = scrolling
        self.launcher = launcher
    }

    func register() {
        KeyboardShortcuts.onKeyUp(for: .captureArea) { [coordinator] in coordinator.capture(.area) }
        KeyboardShortcuts.onKeyUp(for: .captureWindow) { [coordinator] in coordinator.capture(.window) }
        KeyboardShortcuts.onKeyUp(for: .captureFullScreen) { [coordinator] in coordinator.capture(.fullScreen) }
        // Scrolling and recording: the same key picks, then starts from the toolbar, then finishes.
        KeyboardShortcuts.onKeyUp(for: .scrollingCapture) { [scrolling] in scrolling.toggle(.area) }
        KeyboardShortcuts.onKeyUp(for: .scrollingWindow) { [scrolling] in scrolling.toggle(.window) }
        KeyboardShortcuts.onKeyUp(for: .scrollingFullScreen) { [scrolling] in scrolling.toggle(.fullScreen) }
        KeyboardShortcuts.onKeyUp(for: .recordScreen) { [recording] in recording.toggle(.area) }
        KeyboardShortcuts.onKeyUp(for: .recordWindow) { [recording] in recording.toggle(.window) }
        KeyboardShortcuts.onKeyUp(for: .recordFullScreen) { [recording] in recording.toggle(.fullScreen) }
        KeyboardShortcuts.onKeyUp(for: .pauseRecording) { [recording] in recording.togglePause() }
        KeyboardShortcuts.onKeyUp(for: .captureBar) { [launcher] in launcher.open(nil) }
    }
}
