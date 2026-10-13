import AppKit
import ScreenshotXXCore

@Observable
final class CaptureCoordinator {
    private let settings: AppSettings
    private let store: CaptureStore
    private let quickAccess: QuickAccessController
    private let onPermissionMissing: () -> Void
    private var isCapturing = false

    init(settings: AppSettings, store: CaptureStore, quickAccess: QuickAccessController,
         onPermissionMissing: @escaping () -> Void) {
        self.settings = settings
        self.store = store
        self.quickAccess = quickAccess
        self.onPermissionMissing = onPermissionMissing
    }

    func capture(_ kind: CaptureKind) {
        let allowed = PermissionService.hasScreenRecordingAccess
        DiagnosticLog.write("capture(\(kind.rawValue)) screenRecordingAccess=\(allowed)")
        guard allowed else {
            onPermissionMissing()
            return
        }
        guard !isCapturing else { return }
        switch kind {
        case .fullScreen:
            Task { await captureFullScreen() }
        case .area:
            Task { await captureWithOverlay(.area) }
        case .window:
            Task { await captureWithOverlay(.window) }
        }
    }

    private func captureWithOverlay(_ mode: OverlayCaptureSession.Mode) async {
        isCapturing = true
        defer { isCapturing = false }
        do {
            switch try await OverlayCaptureSession.run(mode: mode, showsCursor: settings.showsCursor) {
            case .area(let image):
                DiagnosticLog.write("area selected: \(image.width)x\(image.height) px")
                finish(Capture(kind: .area, image: image))
            case .window(let window):
                let image = try await ScreenCapturer.captureWindow(window, showsCursor: settings.showsCursor, includeShadow: true)
                DiagnosticLog.write("window captured: \(window.title ?? "?") \(image.width)x\(image.height) px")
                finish(Capture(kind: .window, image: image))
            case .cancelled:
                DiagnosticLog.write("overlay cancelled")
            }
        } catch {
            DiagnosticLog.write("overlay capture failed: \(error)")
            ErrorPresenter.show(title: "Capture failed", message: error.localizedDescription)
        }
    }

    private func captureFullScreen() async {
        isCapturing = true
        defer { isCapturing = false }
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
        quickAccess.show(capture, on: .underMouse)
    }
}
