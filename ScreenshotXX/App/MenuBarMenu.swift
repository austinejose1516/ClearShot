import SwiftUI
import ScreenshotXXCore

struct MenuBarMenu: View {
    @Environment(CaptureCoordinator.self) private var coordinator
    @Environment(UpdateChecker.self) private var updates
    let onAbout: () -> Void
    let onSettings: () -> Void

    var body: some View {
        if let version = updates.availableVersion {
            Button("Update Available: \(version)…") { updates.showAvailableUpdate() }
            Divider()
        }
        Button("Capture Area") { coordinator.capture(.area) }
        Button("Capture Window") { coordinator.capture(.window) }
        Button("Capture Full Screen") { coordinator.capture(.fullScreen) }
        Divider()
        Button("About ScreenshotXX", action: onAbout)
        Button("Check for Updates…") { updates.checkNow() }
        Button("Settings…", action: onSettings)
            .keyboardShortcut(",")
        Divider()
        Button("Quit ScreenshotXX") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
