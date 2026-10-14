import AppKit
import ClearShotCore
import SwiftUI

/// Settings in our own window (toolbar tabs, like system apps), so we control how it comes to the front.
/// SwiftUI's built-in Settings scene does not open reliably from a menu bar app.
final class SettingsWindowController: NSWindowController {
    enum Tab: Int {
        case general, recording, shortcuts, cloud, about
    }

    private let tabs = NSTabViewController()

    init(settings: AppSettings, updates: UpdateChecker) {
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(Self.tab("General", symbol: "gearshape", GeneralSettingsTab().environment(updates).themed(settings)))
        tabs.addTabViewItem(Self.tab("Recording", symbol: "record.circle", RecordingSettingsTab().themed(settings)))
        tabs.addTabViewItem(Self.tab("Shortcuts", symbol: "keyboard", ShortcutsSettingsTab().themed(settings)))
        tabs.addTabViewItem(Self.tab("Cloud", symbol: "icloud", CloudSettingsTab().themed(settings)))
        tabs.addTabViewItem(Self.tab("About", symbol: "info.circle", AboutSettingsTab().themed(settings)))
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    /// Switches to a tab (Upload opens Cloud when it is not set up yet).
    func show(_ tab: Tab) {
        tabs.selectedTabViewItemIndex = tab.rawValue
    }

    private static func tab(_ title: String, symbol: String, _ view: some View) -> NSTabViewItem {
        let host = NSHostingController(rootView: view)
        host.title = title   // the tab controller passes the selected tab's title on to the window
        host.sizingOptions = .preferredContentSize
        let item = NSTabViewItem(viewController: host)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }
}
