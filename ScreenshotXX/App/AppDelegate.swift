import AppKit
import ScreenshotXXCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let captureStore = CaptureStore()
    private(set) lazy var captureCoordinator = CaptureCoordinator(settings: settings, store: captureStore) { [weak self] in
        self?.showOnboarding()
    }
    private var hotkeys: HotkeyService?
    private var onboarding: PermissionOnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DiagnosticLog.write("launched build \(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "?") screenRecordingAccess=\(PermissionService.hasScreenRecordingAccess)")
        let hotkeys = HotkeyService(coordinator: captureCoordinator)
        hotkeys.register()
        self.hotkeys = hotkeys

        if !PermissionService.hasScreenRecordingAccess {
            showOnboarding()
        }
    }

    func showOnboarding() {
        let controller = onboarding ?? PermissionOnboardingWindowController()
        onboarding = controller
        controller.showWindow(nil)
        NSApp.activate()
    }
}
