import AppKit
import SwiftUI

final class PermissionOnboardingWindowController: NSWindowController {
    convenience init() {
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
            rootView: PermissionOnboardingView { [weak window] in window?.close() }
        )
        window.center()
    }
}
