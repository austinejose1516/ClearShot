import SwiftUI
import ScreenshotXXCore

@main
struct ScreenshotXXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("ScreenshotXX", systemImage: "camera.viewfinder") {
            MenuBarMenu(onAbout: appDelegate.showAbout, onSettings: appDelegate.showSettings)
                .environment(appDelegate.captureCoordinator)
        }
        .menuBarExtraStyle(.menu)
    }
}
