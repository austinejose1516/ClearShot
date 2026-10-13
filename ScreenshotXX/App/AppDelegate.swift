import AppKit
import ScreenshotXXCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let captureStore = CaptureStore()
    private(set) lazy var quickAccess = QuickAccessController(settings: settings)
    private(set) lazy var captureCoordinator = CaptureCoordinator(settings: settings, store: captureStore,
                                                                  quickAccess: quickAccess) { [weak self] in
        self?.showOnboarding()
    }
    private var hotkeys: HotkeyService?
    private var onboarding: PermissionOnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DiagnosticLog.write("launched build \(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "?") screenRecordingAccess=\(PermissionService.hasScreenRecordingAccess)")
        let hotkeys = HotkeyService(coordinator: captureCoordinator)
        hotkeys.register()
        self.hotkeys = hotkeys

        // Until the editor exists (Phase 6), Edit opens the file with the default app.
        quickAccess.onEdit = { capture in
            DiagnosticLog.write("edit requested for \(capture.id)")
            if let url = capture.fileURL { NSWorkspace.shared.open(url) }
        }

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
