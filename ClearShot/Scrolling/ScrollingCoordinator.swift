import AppKit
import ClearShotCore
import SwiftUI

/// Runs one scrolling capture at a time, the same way as a recording: pick what to capture, choose who
/// scrolls in the toolbar, capture until Done, then hand the tall picture on like any screenshot.
@Observable
final class ScrollingCoordinator {
    enum State: Equatable {
        case idle
        /// The area or window picker is up.
        case choosing
        /// The toolbar is up: who scrolls, Change Area, Start.
        case ready
        case capturing
    }

    private(set) var state: State = .idle

    private let settings: AppSettings
    /// The shared tail of every capture: card, clipboard, file.
    private let onCaptured: (Capture) -> Void
    private let onPermissionMissing: () -> Void

    private var kind: CaptureKind = .area
    private var target: RegionPicker.Target?
    private let toolbarModel = ScrollToolbarModel()
    private var toolbar: ToolbarPanel?
    private var frame: RegionFramePanel?
    private var preview: ScrollPreviewPanel?
    private var session: ScrollingCaptureSession?

    init(settings: AppSettings, onCaptured: @escaping (Capture) -> Void, onPermissionMissing: @escaping () -> Void) {
        self.settings = settings
        self.onCaptured = onCaptured
        self.onPermissionMissing = onPermissionMissing
    }

    /// A scrolling hotkey: pick `kind`, start the one that is ready, or finish the one running.
    func toggle(_ kind: CaptureKind) {
        switch state {
        case .idle: start(kind)
        case .ready: begin()
        case .capturing: finish()
        case .choosing: break
        }
    }

    func start(_ kind: CaptureKind) {
        guard PermissionService.hasScreenRecordingAccess else {
            DiagnosticLog.write("scrolling(\(kind.rawValue)) blocked: no Screen Recording access")
            onPermissionMissing()
            return
        }
        guard state == .idle else { return }
        self.kind = kind
        toolbarModel.mode = .manual
        DiagnosticLog.write("scrolling(\(kind.rawValue)) choosing")
        choose(keeping: nil)
    }

    /// Done: keep what is captured so far.
    func finish() {
        session?.finish()
    }

    /// The toolbar's ✕ or Esc, before or during the capture.
    func cancel() {
        switch state {
        case .ready:
            tearDownPanels()
            state = .idle
            DiagnosticLog.write("scrolling capture cancelled before it started")
        case .capturing:
            session?.cancel()
        case .idle, .choosing:
            break
        }
    }

    // MARK: - Choosing

    /// Opens the picker. Cancelling it goes back to `previous` (Change Area), or ends everything when there is none.
    private func choose(keeping previous: RegionPicker.Target?) {
        state = .choosing
        Task {
            do {
                guard let picked = try await RegionPicker.pick(kind, settings: settings) ?? previous else {
                    DiagnosticLog.write("scrolling(\(kind.rawValue)) cancelled")
                    state = .idle
                    return
                }
                target = picked
                showToolbar(for: picked.region)
            } catch {
                tearDownPanels()
                state = .idle
                DiagnosticLog.write("scrolling(\(kind.rawValue)) could not pick: \(error)")
                ErrorPresenter.show(title: "Could not start the scrolling capture", message: error.localizedDescription)
            }
        }
    }

    private func showToolbar(for region: ScreenRegion) {
        guard let screen = region.screen else {
            state = .idle
            return
        }
        state = .ready
        if !region.coversWholeScreen {
            let frame = RegionFramePanel(region: region)
            frame.orderFrontRegardless()
            frame.reveal()
            self.frame = frame
        }
        let toolbar = ToolbarPanel()
        toolbar.onReturn = { [weak self] in self?.begin() }
        toolbar.onEscape = { [weak self] in self?.cancel() }
        toolbar.show(ScrollToolbarView(
            model: toolbarModel,
            changeTitle: ToolbarChangeButton.title(for: kind),
            onCancel: { [weak self] in self?.cancel() },
            onChange: { [weak self] in self?.changeTarget() },
            onStart: { [weak self] in self?.begin() },
            onPickAuto: { [weak self] in self?.pickAuto() })
            .themed(settings), on: screen)
        self.toolbar = toolbar
        DiagnosticLog.write("scrolling(\(kind.rawValue)) ready: \(Int(region.quartzRect.width))x\(Int(region.quartzRect.height)) pt")
    }

    private func changeTarget() {
        guard state == .ready else { return }
        tearDownPanels()
        choose(keeping: target)
    }

    /// Auto needs the Accessibility permission to scroll other apps. Without it: the system's prompt and the
    /// settings page open, and the switch stays on By hand.
    private func pickAuto() {
        guard PermissionService.hasAccessibilityAccess else {
            DiagnosticLog.write("scrolling: Auto needs Accessibility")
            PermissionService.requestAccessibilityAccess()
            PermissionService.openAccessibilitySettings()
            Toast.show("Allow ClearShot in Accessibility, then pick Auto again", symbol: "hand.raised.fill", on: target?.region.screen)
            return
        }
        toolbarModel.mode = .automatic
    }

    // MARK: - Capturing

    /// The toolbar turns into the bar in the same spot; the preview appears beside the area. Both exist before
    /// the session takes its first picture, so neither is in the page.
    private func begin() {
        guard state == .ready, let target, let screen = target.region.screen, let toolbar else { return }
        let region = target.region
        state = .capturing
        let captureState = ScrollCaptureState(mode: toolbarModel.mode)
        let session = ScrollingCaptureSession(target: target, state: captureState)
        self.session = session
        toolbar.onReturn = { [weak self] in self?.finish() }
        toolbar.show(ScrollBarView(
            state: captureState,
            onDone: { [weak self] in self?.finish() },
            onCancel: { [weak self] in self?.cancel() })
            .themed(settings), on: screen)
        let preview = ScrollPreviewPanel(state: captureState, beside: region)
        preview.reveal()
        self.preview = preview
        DiagnosticLog.write("scrolling capture started (\(captureState.mode == .automatic ? "auto" : "by hand"))")
        Task {
            do {
                let result = try await session.run()
                tearDownPanels()
                self.session = nil
                state = .idle
                guard let result else { return }
                onCaptured(Capture(kind: .scrolling, image: result.image, pageCount: result.pages))
            } catch {
                tearDownPanels()
                self.session = nil
                state = .idle
                DiagnosticLog.write("scrolling capture failed: \(error)")
                ErrorPresenter.show(title: "Scrolling capture failed", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Panels

    private func tearDownPanels() {
        for panel in [toolbar, frame, preview] as [NSPanel?] {
            panel?.orderOut(nil)
            panel?.contentView = nil
        }
        toolbar = nil
        frame = nil
        preview = nil
    }
}
