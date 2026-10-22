import KeyboardShortcuts
import SwiftUI
import ClearShotCore

/// The menu bar menu: Screenshot, Scrolling Capture and Record each open the capture bar, where Area, Window
/// or Full screen is picked. While a recording or a scrolling capture runs, its controls come first, one
/// click away.
struct MenuBarMenu: View {
    @Environment(CaptureLauncher.self) private var launcher
    @Environment(RecordingCoordinator.self) private var recording
    @Environment(ScrollingCoordinator.self) private var scrolling
    @Environment(UpdateChecker.self) private var updates
    let onAbout: () -> Void
    let onSettings: () -> Void

    var body: some View {
        if let version = updates.availableVersion {
            item("Update Available: \(version)…", "arrow.down.circle") { updates.showAvailableUpdate() }
            Divider()
        }

        if running {
            recordingControls
            scrollingControls
            Divider()
        }

        item("Screenshot", CaptureAction.screenshot.symbol) { launcher.open(.screenshot) }
        item("Scrolling Capture", CaptureAction.scrolling.symbol) { launcher.open(.scrolling) }
            .disabled(scrolling.state != .idle)
        item("Record", CaptureAction.recording.symbol) { launcher.open(.recording) }
            .disabled(recording.state != .idle)

        Divider()
        item("About ClearShot", "info.circle", action: onAbout)
        item("Check for Updates…", "arrow.triangle.2.circlepath") { updates.checkNow() }
        item("Settings…", "gearshape", action: onSettings)
            .keyboardShortcut(",")
        Divider()
        item("Quit ClearShot", "power") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// A recording or a scrolling capture is under way (its toolbar is up, or it is running).
    private var running: Bool {
        !(recording.state == .idle || recording.state == .choosing) || !(scrolling.state == .idle || scrolling.state == .choosing)
    }

    @ViewBuilder private var recordingControls: some View {
        switch recording.state {
        case .recording:
            item("Pause Recording", "pause.fill", .pauseRecording) { recording.pause() }
            item("Stop Recording", "stop.fill", .recordScreen) { recording.stop() }
        case .paused:
            item("Resume Recording", "record.circle", .pauseRecording) { recording.resume() }
            item("Stop Recording", "stop.fill", .recordScreen) { recording.stop() }
        case .ready, .countdown:
            item("Cancel Recording", "xmark") { recording.cancel() }
        case .idle, .choosing:
            EmptyView()
        }
    }

    @ViewBuilder private var scrollingControls: some View {
        switch scrolling.state {
        case .capturing:
            item("Finish Scrolling Capture", "checkmark", .scrollingCapture) { scrolling.finish() }
            item("Cancel Scrolling Capture", "xmark") { scrolling.cancel() }
        case .ready:
            item("Cancel Scrolling Capture", "xmark") { scrolling.cancel() }
        case .idle, .choosing:
            EmptyView()
        }
    }

    /// One menu item: an icon, a title, and the global shortcut that does the same (if there is one).
    @ViewBuilder
    private func item(_ title: String, _ symbol: String, _ shortcut: KeyboardShortcuts.Name? = nil,
                      action: @escaping () -> Void) -> some View {
        // In a Mac menu, SwiftUI shows only a label's title unless the style asks for the icon too.
        let button = Button(action: action) { Label(title, systemImage: symbol).labelStyle(.titleAndIcon) }
        if let shortcut {
            button.globalKeyboardShortcut(shortcut)
        } else {
            button
        }
    }
}
