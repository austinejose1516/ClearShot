import SwiftUI
import ClearShotCore

@main
struct ClearShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("ClearShot", systemImage: "camera.viewfinder") {
            MenuBarMenu(onAbout: appDelegate.showAbout, onSettings: { appDelegate.showSettings() })
                .environment(appDelegate.captureCoordinator)
                .environment(appDelegate.updates)
        }
        .menuBarExtraStyle(.menu)
    }
}
