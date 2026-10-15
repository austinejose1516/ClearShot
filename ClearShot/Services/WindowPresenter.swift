import AppKit
import ClearShotCore

/// Brings our windows to the front like a normal app.
///
/// A menu-bar-only app (activation policy `.accessory`) is treated by macOS as a background helper: its windows
/// open behind other apps and Stage Manager keeps them off centre stage. The usual fix for menu bar apps is to
/// act as a regular app (with a Dock icon) while one of our windows is open, and to go back to menu-bar-only
/// when the last one closes.
@MainActor
enum WindowPresenter {
    private static var closeObserver: NSObjectProtocol?

    /// Shows one of our windows in front, active, and in Stage Manager's centre.
    static func show(_ window: NSWindow) {
        becomeRegularApp()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        // Activation straight after a policy change can be refused; ask once more a moment later.
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            DiagnosticLog.write("shown \(window.title.isEmpty ? "window" : window.title): app active=\(NSApp.isActive) key=\(window.isKeyWindow)")
        }
    }

    /// Before a window AppKit creates for us (About panel, alerts).
    static func becomeRegularApp() {
        watchWindowCloses()
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
        NSApp.activate()
    }

    /// Back to menu-bar-only once none of our titled windows is open. Cards and capture overlays are borderless,
    /// so they do not count.
    static func returnToMenuBarIfNoWindows() {
        let anyOpen = NSApp.windows.contains { window in
            window.styleMask.contains(.titled) && (window.isVisible || window.isMiniaturized)
        }
        if !anyOpen, NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private static func watchWindowCloses() {
        guard closeObserver == nil else { return }
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { _ in
            // The closing window is still visible during this notification; check once it is gone.
            Task { @MainActor in returnToMenuBarIfNoWindows() }
        }
    }
}
