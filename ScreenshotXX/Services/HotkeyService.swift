import KeyboardShortcuts
import ScreenshotXXCore

extension KeyboardShortcuts.Name {
    static let captureArea = Self("captureArea", initial: .init(.a, modifiers: [.control, .shift]))
    static let captureWindow = Self("captureWindow", initial: .init(.w, modifiers: [.control, .shift]))
    static let captureFullScreen = Self("captureFullScreen", initial: .init(.f, modifiers: [.control, .shift]))
}

final class HotkeyService {
    private let coordinator: CaptureCoordinator

    init(coordinator: CaptureCoordinator) {
        self.coordinator = coordinator
    }

    func register() {
        KeyboardShortcuts.onKeyUp(for: .captureArea) { [coordinator] in coordinator.capture(.area) }
        KeyboardShortcuts.onKeyUp(for: .captureWindow) { [coordinator] in coordinator.capture(.window) }
        KeyboardShortcuts.onKeyUp(for: .captureFullScreen) { [coordinator] in coordinator.capture(.fullScreen) }
    }
}
