import AppKit
import ClearShotCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    private(set) lazy var quickAccess = QuickAccessController(settings: settings)
    private(set) lazy var captureCoordinator = CaptureCoordinator(settings: settings, quickAccess: quickAccess) { [weak self] in
        self?.showOnboarding()
    }
    private(set) lazy var recording = RecordingCoordinator(settings: settings, quickAccess: quickAccess) { [weak self] in
        self?.showOnboarding()
    }
    private(set) lazy var scrolling = ScrollingCoordinator(
        settings: settings,
        onCaptured: { [weak self] in self?.captureCoordinator.deliver($0) },
        onPermissionMissing: { [weak self] in self?.showOnboarding() })
    private(set) lazy var launcher = CaptureLauncher(settings: settings, captures: captureCoordinator, recording: recording,
                                                     scrolling: scrolling) { [weak self] in self?.showOnboarding() }
    private var hotkeys: HotkeyService?
    private var onboarding: PermissionOnboardingWindowController?
    private(set) lazy var updates = UpdateChecker(settings: settings)
    private lazy var settingsWindow = SettingsWindowController(settings: settings, updates: updates)
    private lazy var uploadsWindow = UploadsWindowController(settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        DiagnosticLog.write("launched build \(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "?") screenRecordingAccess=\(PermissionService.hasScreenRecordingAccess)")
        Theme.apply(settings.appearance)
        let hotkeys = HotkeyService(coordinator: captureCoordinator, recording: recording, scrolling: scrolling, launcher: launcher)
        hotkeys.register()
        self.hotkeys = hotkeys

        quickAccess.onEdit = { [settings] capture in
            if capture.isVideo {
                VideoEditorStore.shared.open(capture: capture, settings: settings)
            } else {
                EditorSessionStore.shared.open(capture: capture, settings: settings)
            }
        }
        // Editors end with Done; the card takes the result, saves it, and keeps Copy, Share and Upload.
        EditorSessionStore.shared.onDone = { [weak self] captureID, image in
            self?.quickAccess.editorDone(captureID, image: image)
        }
        VideoEditorStore.shared.onSaved = { [weak self] captureID, result in
            self?.quickAccess.savedVideo(captureID, duration: result.duration, poster: result.poster,
                                         encoding: result.encoding, at: result.url)
        }
        CardTransition.cards = quickAccess
        quickAccess.onDismissed = { captureID in
            EditorSessionStore.shared.cardDismissed(captureID)
            VideoEditorStore.shared.cardDismissed(captureID)
        }
        quickAccess.onDelete = { capture in
            EditorSessionStore.shared.close(captureID: capture.id)
            VideoEditorStore.shared.close(captureID: capture.id)
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

    /// The Uploads window: what is in the cloud bucket, with copy link, open and delete.
    func showUploads() {
        uploadsWindow.show()
    }

    func showAbout() {
        AppInfo.showAboutPanel()
    }
}
