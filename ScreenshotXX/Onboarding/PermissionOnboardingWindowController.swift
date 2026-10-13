import AppKit
import ScreenshotXXCore
import SwiftUI

final class PermissionOnboardingWindowController: NSWindowController {
    convenience init(settings: AppSettings) {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.contentViewController = NSHostingController(
            rootView: PermissionOnboardingView { [weak window] in window?.close() }.themed(settings)
        )
        window.center()
    }
}
