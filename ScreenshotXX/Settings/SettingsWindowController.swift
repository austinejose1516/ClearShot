import AppKit
import ScreenshotXXCore
import SwiftUI

/// Settings in our own window (toolbar tabs, like system apps), so we control how it comes to the front.
/// SwiftUI's built-in Settings scene does not open reliably from a menu bar app.
final class SettingsWindowController: NSWindowController {
    convenience init(settings: AppSettings, updates: UpdateChecker) {
        let tabs = SettingsTabsController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(Self.tab("General", symbol: "gearshape", GeneralSettingsTab().environment(updates).themed(settings)))
        tabs.addTabViewItem(Self.tab("Shortcuts", symbol: "keyboard", ShortcutsSettingsTab().themed(settings)))
        tabs.addTabViewItem(Self.tab("About", symbol: "info.circle", AboutSettingsTab().themed(settings)))
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.title = tabs.tabViewItems.first?.label ?? "Settings"
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

/// Shows the selected tab's name as the window title, like System Settings panes.
private final class SettingsTabsController: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        view.window?.title = tabViewItem?.label ?? "Settings"
    }
}
