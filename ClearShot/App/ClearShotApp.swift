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

/// The camera, a record dot while a recording runs, or a pause sign while it is paused.
private struct MenuBarLabel: View {
    @Environment(RecordingCoordinator.self) private var recording

    var body: some View {
        Image(systemName: symbol)
    }

    private var symbol: String {
        switch recording.state {
        case .recording: "record.circle.fill"
        case .paused: "pause.circle.fill"
        default: "camera.viewfinder"
        }
    }
}
