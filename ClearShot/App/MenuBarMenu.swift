import KeyboardShortcuts
import SwiftUI
import ClearShotCore

/// The menu bar menu: one row per kind of capture, each opening Area / Window / Full Screen with their
/// shortcuts (they follow Settings → Shortcuts). While a recording or a scrolling capture runs, its controls
/// come first, one click away.
struct MenuBarMenu: View {
    @Environment(CaptureCoordinator.self) private var coordinator
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

        kind("Screenshot", "camera.viewfinder",
             area: (.captureArea, { coordinator.capture(.area) }),
             window: (.captureWindow, { coordinator.capture(.window) }),
             fullScreen: (.captureFullScreen, { coordinator.capture(.fullScreen) }))
        kind("Scrolling Capture", "arrow.up.and.down",
             area: (.scrollingCapture, { scrolling.start(.area) }),
             window: (.scrollingWindow, { scrolling.start(.window) }),
             fullScreen: (.scrollingFullScreen, { scrolling.start(.fullScreen) }))
            .disabled(scrolling.state != .idle)
        kind("Record", "record.circle",
             area: (.recordScreen, { recording.start(.area) }),
             window: (.recordWindow, { recording.start(.window) }),
             fullScreen: (.recordFullScreen, { recording.start(.fullScreen) }))
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

    private typealias Choice = (shortcut: KeyboardShortcuts.Name, action: () -> Void)

    /// One kind of capture: a row that opens Area, Window and Full Screen.
    private func kind(_ title: String, _ symbol: String, area: Choice, window: Choice, fullScreen: Choice) -> some View {
        Menu {
            item("Area", "rectangle.dashed", area.shortcut, action: area.action)
            item("Window", "macwindow", window.shortcut, action: window.action)
            item("Full Screen", "display", fullScreen.shortcut, action: fullScreen.action)
        } label: {
            Label(title, systemImage: symbol).labelStyle(.titleAndIcon)
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
