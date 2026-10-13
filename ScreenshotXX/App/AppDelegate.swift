import AppKit
import ScreenshotXXCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    private(set) lazy var quickAccess = QuickAccessController(settings: settings)
    private(set) lazy var captureCoordinator = CaptureCoordinator(settings: settings, quickAccess: quickAccess) { [weak self] in
        self?.showOnboarding()
    }
    private var hotkeys: HotkeyService?
    private var onboarding: PermissionOnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DiagnosticLog.write("launched build \(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "?") screenRecordingAccess=\(PermissionService.hasScreenRecordingAccess)")
        let hotkeys = HotkeyService(coordinator: captureCoordinator)
        hotkeys.register()
        self.hotkeys = hotkeys

        quickAccess.onEdit = { capture in
            DiagnosticLog.write("edit requested for \(capture.id)")
            EditorSessionStore.shared.open(capture: capture)
        }
        EditorSessionStore.shared.onFinished = { [weak self] captureID in
            self?.quickAccess.close(id: captureID)
        }
        quickAccess.onDismissed = { captureID in
            EditorSessionStore.shared.cardDismissed(captureID)
        }
        quickAccess.onDelete = { capture in
            EditorSessionStore.shared.close(captureID: capture.id)
            guard let url = capture.fileURL else { return }
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                DiagnosticLog.write("moved to trash: \(url.path(percentEncoded: false))")
            } catch {
                ErrorPresenter.show(title: "Could not move to Trash", message: error.localizedDescription)
            }
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
