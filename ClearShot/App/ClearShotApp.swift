import AppKit
import SwiftUI
import ClearShotCore

@main
struct ClearShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu(onAbout: appDelegate.showAbout, onSettings: { appDelegate.showSettings() })
                .environment(appDelegate.captureCoordinator)
                .environment(appDelegate.recording)
                .environment(appDelegate.scrolling)
                .environment(appDelegate.updates)
        } label: {
            MenuBarLabel().environment(appDelegate.recording)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// The app's glyph (the app icon, small), a record dot while a recording runs, or a pause sign while it is paused.
private struct MenuBarLabel: View {
    @Environment(RecordingCoordinator.self) private var recording

    var body: some View {
        switch recording.state {
        case .recording: Image(systemName: "record.circle.fill")
        case .paused: Image(systemName: "pause.circle.fill")
        default: Image(nsImage: Self.glyph)
        }
    }

    /// `MenuBarIcon.png` (drawn by `scripts/make-icon.swift`) as a template image, so it takes the menu bar's colour.
    private static let glyph: NSImage = {
        let image = NSImage(named: "MenuBarIcon") ?? NSImage()
        image.isTemplate = true
        return image
    }()
}
