import SwiftUI
import ScreenshotXXCore

@main
struct ScreenshotXXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("ScreenshotXX", systemImage: "camera.viewfinder") {
            MenuBarMenu()
                .environment(appDelegate.captureCoordinator)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(appDelegate.settings)
        }
    }
}
