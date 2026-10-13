import SwiftUI
import ScreenshotXXCore

struct MenuBarMenu: View {
    @Environment(CaptureCoordinator.self) private var coordinator
    let onAbout: () -> Void
    let onSettings: () -> Void

    var body: some View {
        Button("Capture Area") { coordinator.capture(.area) }
        Button("Capture Window") { coordinator.capture(.window) }
        Button("Capture Full Screen") { coordinator.capture(.fullScreen) }
        Divider()
        Button("About ScreenshotXX", action: onAbout)
        Button("Settings…", action: onSettings)
            .keyboardShortcut(",")
        Divider()
        Button("Quit ScreenshotXX") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
