import AppKit
import ClearShotCore

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
        // It stays set until the file is written, so the next capture never picks the same file name.
        guard !isCapturing else { return }
        isCapturing = true
        Task {
            defer { isCapturing = false }
            do {
                guard let capture = try await makeCapture(kind) else {
                    DiagnosticLog.write("capture(\(kind.rawValue)) cancelled")
                    return
                }
                await finish(capture)
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
            switch try await OverlayCaptureSession.run(mode: kind == .area ? .area : .window, settings: settings) {
            case .area(let image, _):
                return Capture(kind: .area, image: image)
            case .window(let window):
                // Both at once: the shadowed one is saved, the plain one is what the editor starts from.
                let showsCursor = settings.showsCursor
                let started = ContinuousClock.now
                let plain = Task { try? await ScreenCapturer.captureWindow(window, showsCursor: showsCursor, includeShadow: false) }
                let image = try await ScreenCapturer.captureWindow(window, showsCursor: showsCursor, includeShadow: true)
                let windowImage = await plain.value
                DiagnosticLog.write("window captured twice in \((ContinuousClock.now - started).formatted(.units(allowed: [.milliseconds])))")
                return Capture(kind: .window, image: image, windowImage: windowImage)
            case .cancelled:
                return nil
            }
        case .scrolling:
            let region: ScreenRegion
            switch try await OverlayCaptureSession.run(mode: .area, settings: settings) {
            case .area(_, let picked):
                region = picked
            case .window(let window):
                let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
                let screen = NSScreen.screens.first { ScreenCoordinates.quartzRect(fromAppKit: $0.frame, primaryHeight: NSScreen.screens.first?.frame.height ?? 0).contains(center) } ?? .main
                region = ScreenRegion(displayID: screen?.displayID ?? 0, quartzRect: window.frame, scale: screen?.backingScaleFactor ?? 2)
            case .cancelled:
                return nil
            }
            guard let mode = scrollingMode() else { return nil }
            guard let result = try await ScrollingCaptureSession.run(region: region, mode: mode) else { return nil }
            return Capture(kind: .scrolling, image: result.image, pageCount: result.pages)
        }
    }

    /// Automatic when ClearShot may scroll other apps; otherwise the user chooses: allow it, scroll by hand, or stop.
    private func scrollingMode() -> ScrollHUDState.Mode? {
        guard !PermissionService.hasAccessibilityAccess else { return .automatic }
        let alert = NSAlert()
        alert.messageText = "Let ClearShot scroll the page for you?"
        alert.informativeText = "To scroll other apps, ClearShot needs the Accessibility permission: System Settings → Privacy & Security → Accessibility. Allow it there, then start again.\n\nOr scroll by hand: scroll down yourself and press Enter when you reach the end."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Scroll by Hand")
        alert.addButton(withTitle: "Cancel")
        WindowPresenter.becomeRegularApp()
        let answer = alert.runModal()
        WindowPresenter.returnToMenuBarIfNoWindows()
        switch answer {
        case .alertFirstButtonReturn:
            PermissionService.requestAccessibilityAccess()
            PermissionService.openAccessibilitySettings()
            return nil
        case .alertSecondButtonReturn:
            return .manual
        default:
            return nil
        }
    }

    /// Shared tail of every capture. The card comes first: encoding a Retina screenshot takes 50–400 ms, so it
    /// runs off the main thread while the card animates in. Then the clipboard, then the file, whose type is
    /// only known once it is encoded (a photo may become a JPEG to stay under the size budget).
    private func finish(_ capture: Capture) async {
        let format = settings.imageFormat
        let copies = settings.copiesToClipboard
        // A scrolling shot gets the budget once per page, so a long page is not crushed into a blurry JPEG.
        let budget = settings.fileBudget.map { $0 * capture.pageCount }
        let folder = settings.saveFolder
        CaptureFlash.flash(on: .underMouse)
        if settings.playsSound { SoundPlayer.playShutter() }
        quickAccess.show(capture, on: .underMouse)

        let image = capture.image
        let started = ContinuousClock.now
        let encoded = await Task.detached { () -> (file: Result<FileSaver.EncodedImage, any Error>, png: Data?) in
            // The clipboard always gets the full PNG; the file follows the format and the size budget.
            let file = Result { try FileSaver.encode(image, preferring: format, budget: budget) }
            guard copies else { return (file, nil) }
            let png = (try? file.get().standardPNG) ?? nil
            return (file, png ?? (try? FileSaver.encode(image, format: .png)))
        }.value
        if let png = encoded.png { ClipboardService.copy(png: png, of: image) }
        do {
            let file = try encoded.file.get()
            let url = try FileSaver.reserveURL(for: file.format, in: folder, date: capture.createdAt)
            try file.data.write(to: url)
            quickAccess.fileWritten(capture.id, at: url)
            DiagnosticLog.write("saved \(capture.kind.rawValue) \(image.width)x\(image.height) px as \(file.format.rawValue), \(file.data.count / 1024) KB, encoded in \((ContinuousClock.now - started).formatted(.units(allowed: [.milliseconds])))")
        } catch {
            DiagnosticLog.write("save failed: \(error)")
            ErrorPresenter.show(title: "Could not save the screenshot",
                                message: "\(error.localizedDescription)\n\nIt is still on your clipboard.")
        }
    }
}
