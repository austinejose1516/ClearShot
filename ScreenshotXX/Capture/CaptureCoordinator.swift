import AppKit
import os
import ScreenshotXXCore

@Observable
final class CaptureCoordinator {
    private let settings: AppSettings
    private let store: CaptureStore
    private let onPermissionMissing: () -> Void
    @ObservationIgnored private let log = Logger(subsystem: "com.austinejose.screenshotxx", category: "capture")

    init(settings: AppSettings, store: CaptureStore, onPermissionMissing: @escaping () -> Void) {
        self.settings = settings
        self.store = store
        self.onPermissionMissing = onPermissionMissing
    }

    func capture(_ kind: CaptureKind) {
        let allowed = PermissionService.hasScreenRecordingAccess
        DiagnosticLog.write("capture(\(kind.rawValue)) screenRecordingAccess=\(allowed)")
        guard allowed else {
            onPermissionMissing()
            return
        }
        switch kind {
        case .fullScreen:
            Task { await captureFullScreen() }
        case .area, .window:
            log.notice("capture requested: \(kind.rawValue, privacy: .public) (not implemented yet)")
        }
    }

    private func captureFullScreen() async {
        do {
            let display = try await ScreenCapturer.display(under: NSEvent.mouseLocation)
            DiagnosticLog.write("display found: id=\(display.displayID) \(display.width)x\(display.height) pt")
            let image = try await ScreenCapturer.captureDisplay(display, showsCursor: settings.showsCursor)
            DiagnosticLog.write("image captured: \(image.width)x\(image.height) px")
            finish(Capture(kind: .fullScreen, image: image))
        } catch {
            DiagnosticLog.write("capture failed: \(error)")
            ErrorPresenter.show(title: "Capture failed", message: error.localizedDescription)
        }
    }

    /// Shared tail of every capture: clipboard first (never lost), then disk, then sound and store.
    private func finish(_ capture: Capture) {
        var capture = capture
        if settings.copiesToClipboard { ClipboardService.copy(capture.image) }
        do {
            capture.fileURL = try FileSaver.save(capture.image, format: settings.imageFormat,
                                                 to: settings.saveFolder, date: capture.createdAt)
            DiagnosticLog.write("saved: \(capture.fileURL?.path(percentEncoded: false) ?? "-")")
        } catch {
            DiagnosticLog.write("save failed: \(error)")
            ErrorPresenter.show(title: "Could not save the screenshot",
                                message: "\(error.localizedDescription)\n\nIt is still on your clipboard.")
        }
        if settings.playsSound { SoundPlayer.playShutter() }
        store.add(capture)
    }
}
