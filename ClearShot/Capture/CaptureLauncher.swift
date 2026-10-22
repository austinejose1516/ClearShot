import AppKit
import ClearShotCore

/// Opens the capture bar (the frozen screens with the bar at the bottom) and hands what was picked to the
/// right place: a screenshot is taken at once; a scrolling capture or a recording goes on to its toolbar.
/// The shortcuts do not come through here: each goes straight to its pick, as before.
@Observable
@MainActor
final class CaptureLauncher {
    private let settings: AppSettings
    private let captures: CaptureCoordinator
    private let recording: RecordingCoordinator
    private let scrolling: ScrollingCoordinator
    private let onPermissionMissing: () -> Void
    private(set) var isOpen = false

    init(settings: AppSettings, captures: CaptureCoordinator, recording: RecordingCoordinator, scrolling: ScrollingCoordinator,
         onPermissionMissing: @escaping () -> Void) {
        self.settings = settings
        self.captures = captures
        self.recording = recording
        self.scrolling = scrolling
        self.onPermissionMissing = onPermissionMissing
    }

    /// Opens the bar on `action` (a menu item), or on whatever was used last (the bar's own shortcut). Nothing
    /// happens while a recording or a scrolling capture is under way.
    func open(_ action: CaptureAction?) {
        guard PermissionService.hasScreenRecordingAccess else {
            DiagnosticLog.write("capture bar blocked: no Screen Recording access")
            onPermissionMissing()
            return
        }
        guard !isOpen, recording.state == .idle, scrolling.state == .idle else { return }
        let bar = CaptureBarModel.remembered(from: settings, action: action)
        isOpen = true
        DiagnosticLog.write("capture bar opened on \(bar.action.rawValue), picking \(bar.pickMode.rawValue)")
        Task {
            defer { isOpen = false }
            do {
                let outcome = try await OverlayCaptureSession.run(bar: bar, showsBar: true, settings: settings)
                bar.remember(in: settings)
                if case .cancelled = outcome {
                    DiagnosticLog.write("capture bar cancelled")
                    return
                }
                switch bar.action {
                case .screenshot:
                    captures.deliver(outcome)
                case .scrolling:
                    if let target = try await RegionPicker.target(from: outcome) {
                        scrolling.start(with: target, kind: bar.pickMode.kind)
                    }
                case .recording:
                    if let target = try await RegionPicker.target(from: outcome) {
                        recording.start(with: target.region, kind: bar.pickMode.kind)
                    }
                }
            } catch {
                DiagnosticLog.write("capture bar failed: \(error)")
                ErrorPresenter.show(title: "Capture failed", message: error.localizedDescription)
            }
        }
    }
}
