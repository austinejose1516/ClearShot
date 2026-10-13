import AppKit
import ScreenshotXXCore

@Observable
final class CaptureCoordinator {
    private let settings: AppSettings
    private let quickAccess: QuickAccessController
    private let onPermissionMissing: () -> Void
    private var isCapturing = false

    init(settings: AppSettings, quickAccess: QuickAccessController, onPermissionMissing: @escaping () -> Void) {
        self.settings = settings
        self.quickAccess = quickAccess
        self.onPermissionMissing = onPermissionMissing
    }

    func capture(_ kind: CaptureKind) {
        guard PermissionService.hasScreenRecordingAccess else {
            DiagnosticLog.write("capture(\(kind.rawValue)) blocked: no Screen Recording access")
            onPermissionMissing()
            return
        }
        // Set before the task starts, so a fast second hotkey press cannot start a second capture.
        guard !isCapturing else { return }
        isCapturing = true
        Task {
            defer { isCapturing = false }
            do {
                guard let capture = try await makeCapture(kind) else {
                    DiagnosticLog.write("capture(\(kind.rawValue)) cancelled")
                    return
                }
                finish(capture)
            } catch {
                DiagnosticLog.write("capture(\(kind.rawValue)) failed: \(error)")
                ErrorPresenter.show(title: "Capture failed", message: error.localizedDescription)
            }
        }
    }

    /// The image for one capture; nil when the user cancelled.
    private func makeCapture(_ kind: CaptureKind) async throws -> Capture? {
        switch kind {
        case .fullScreen:
            let content = try await ScreenCapturer.content()
            let display = try ScreenCapturer.display(for: .underMouse, in: content)
            return Capture(kind: .fullScreen, image: try await ScreenCapturer.captureDisplay(display, showsCursor: settings.showsCursor))
        case .area, .window:
            switch try await OverlayCaptureSession.run(mode: kind == .area ? .area : .window, showsCursor: settings.showsCursor) {
            case .area(let image):
                return Capture(kind: .area, image: image)
            case .window(let window):
                let image = try await ScreenCapturer.captureWindow(window, showsCursor: settings.showsCursor, includeShadow: true)
                return Capture(kind: .window, image: image)
            case .cancelled:
                return nil
            }
        }
    }

    /// Shared tail of every capture: clipboard first (never lost), then disk, then sound and card.
    private func finish(_ capture: Capture) {
        var capture = capture
        CaptureFlash.flash(on: .underMouse)
        if settings.copiesToClipboard { ClipboardService.copy(capture.image) }
        do {
            capture.fileURL = try FileSaver.save(capture.image, format: settings.imageFormat,
                                                 to: settings.saveFolder, date: capture.createdAt)
            DiagnosticLog.write("saved \(capture.kind.rawValue) \(capture.image.width)x\(capture.image.height) px")
        } catch {
            DiagnosticLog.write("save failed: \(error)")
            ErrorPresenter.show(title: "Could not save the screenshot",
                                message: "\(error.localizedDescription)\n\nIt is still on your clipboard.")
        }
        if settings.playsSound { SoundPlayer.playShutter() }
        quickAccess.show(capture, on: .underMouse)
    }
}
