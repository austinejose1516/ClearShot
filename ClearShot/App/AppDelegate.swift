import AppKit
import ClearShotCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    private(set) lazy var quickAccess = QuickAccessController(settings: settings)
    private(set) lazy var captureCoordinator = CaptureCoordinator(settings: settings, quickAccess: quickAccess) { [weak self] in
        self?.showOnboarding()
    }
    private(set) lazy var recording = RecordingCoordinator(settings: settings) { [weak self] in
        self?.showOnboarding()
    }
    private var hotkeys: HotkeyService?
    private var onboarding: PermissionOnboardingWindowController?
    private(set) lazy var updates = UpdateChecker(settings: settings)
    private lazy var settingsWindow = SettingsWindowController(settings: settings, updates: updates)

    func applicationDidFinishLaunching(_ notification: Notification) {
        DiagnosticLog.write("launched build \(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "?") screenRecordingAccess=\(PermissionService.hasScreenRecordingAccess)")
        Theme.apply(settings.appearance)
        let hotkeys = HotkeyService(coordinator: captureCoordinator, recording: recording)
        hotkeys.register()
        self.hotkeys = hotkeys

        quickAccess.onEdit = { [settings] capture in
            EditorSessionStore.shared.open(capture: capture, settings: settings)
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

        TemporaryFiles.sweepRecordings()

        updates.startAutomaticChecks()

        if !PermissionService.hasScreenRecordingAccess {
            showOnboarding()
        }
    }

    func showOnboarding() {
        let controller = onboarding ?? PermissionOnboardingWindowController(settings: settings)
        onboarding = controller
        controller.window.map(WindowPresenter.show)
    }

    func showSettings(tab: SettingsWindowController.Tab? = nil) {
        if let tab { settingsWindow.show(tab) }
        settingsWindow.window.map(WindowPresenter.show)
    }

    func showAbout() {
        AppInfo.showAboutPanel()
    }
}
