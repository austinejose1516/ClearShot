import AppKit
import ScreenshotXXCore
import SwiftUI

/// Settings in our own window (toolbar tabs, like system apps), so we control how it comes to the front.
/// SwiftUI's built-in Settings scene does not open reliably from a menu bar app.
final class SettingsWindowController: NSWindowController {
    convenience init(settings: AppSettings) {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(Self.tab("General", symbol: "gearshape", GeneralSettingsTab().environment(settings)))
        tabs.addTabViewItem(Self.tab("Shortcuts", symbol: "keyboard", ShortcutsSettingsTab()))
        tabs.addTabViewItem(Self.tab("About", symbol: "info.circle", AboutSettingsTab()))
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.center()
    }

    private static func tab(_ title: String, symbol: String, _ view: some View) -> NSTabViewItem {
        let host = NSHostingController(rootView: view)
        host.sizingOptions = .preferredContentSize
        let item = NSTabViewItem(viewController: host)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }
}
