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
                .environment(appDelegate.updates)
        } label: {
            MenuBarLabel().environment(appDelegate.recording)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// The camera, or a record dot while a recording runs.
private struct MenuBarLabel: View {
    @Environment(RecordingCoordinator.self) private var recording

    var body: some View {
        Image(systemName: recording.isRecording ? "record.circle.fill" : "camera.viewfinder")
    }
}
