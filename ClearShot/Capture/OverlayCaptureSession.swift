import AppKit
import ScreenCaptureKit
import ClearShotCore
import SwiftUI

/// One capture: a see-through overlay dims every screen (with the capture bar on the screen under the mouse,
/// when asked); it resolves on a drag, a window click, a screen click or Esc. The screens go on moving under
/// the dim, and an area or a screen is pictured at the moment it is picked, so a playing video is shot on the
/// frame wanted.
@MainActor
final class OverlayCaptureSession {
    enum Outcome {
        /// The picked area as it was at the moment of the pick, and where it sits on screen (recording and
        /// scrolling capture need the place).
        case area(CGImage, ScreenRegion)
        case window(SCWindow)
        /// A whole screen as it was at the moment of the pick, and its place.
        case fullScreen(CGImage, ScreenRegion)
        case cancelled
    }

    private let state: OverlayState
    private var panels: [SelectionOverlayWindow] = []
    private var windowsByID: [UInt32: SCWindow] = [:]
    /// The window list taken once the overlay is on screen, so a shot can leave ClearShot's own windows out.
    private var contentUnderOverlay: SCShareableContent?
    private var isTakingShot = false
    private var continuation: CheckedContinuation<Outcome, any Error>?

    private init(bar: CaptureBarModel, showsBar: Bool) {
        state = OverlayState(bar: bar, showsBar: showsBar)
    }

    /// The picker alone, starting in `mode`: what the shortcuts and Change Area use.
    static func run(mode: PickMode, settings: AppSettings) async throws -> Outcome {
        try await run(bar: CaptureBarModel(action: .screenshot, pickMode: mode), showsBar: false, settings: settings)
    }

    /// The picker with the capture bar. The bar's choices are read by the caller when this returns.
    static func run(bar: CaptureBarModel, showsBar: Bool, settings: AppSettings) async throws -> Outcome {
        try await OverlayCaptureSession(bar: bar, showsBar: showsBar).start(settings: settings)
    }

    private func start(settings: AppSettings) async throws -> Outcome {
        let content = try await ScreenCapturer.content()
        let screens = ScreenCapturer.screenDisplays(in: content).map(\.screen)
        guard !screens.isEmpty else { throw ScreenCapturer.Failure.noDisplay }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        windowsByID = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
        state.windows = WindowPicker.candidates(
            content.windows.map(WindowInfo.init),
            excludingBundleID: Bundle.main.bundleIdentifier ?? "",
            screens: NSScreen.screens.map { ScreenCoordinates.quartzRect(fromAppKit: $0.frame, primaryHeight: primaryHeight) })

        let mouse = NSEvent.mouseLocation
        let screenUnderMouse = screens.first { $0.frame.contains(mouse) } ?? screens.first
        for screen in screens {
            let panel = SelectionOverlayWindow(screen: screen)
            panel.onCancel = { [weak self] in self?.resolve(.success(.cancelled)) }
            panel.onToggleMode = { [state] in state.pickMode = state.pickMode.afterSpace }
            let quartzFrame = ScreenCoordinates.quartzRect(fromAppKit: screen.frame, primaryHeight: primaryHeight)
            let screenSize = screen.frame.size
            let scale = screen.backingScaleFactor
            let displayID = screen.displayID ?? 0
            let wholeScreen = ScreenRegion(displayID: displayID, quartzRect: quartzFrame, scale: scale)
            let view = CaptureOverlayView(
                screenQuartzFrame: quartzFrame,
                state: state,
                underMouse: screen == screenUnderMouse,
                bottomInset: screen.visibleFrame.minY - screen.frame.minY + ToolbarPanel.bottomGap,
                onSelectArea: { [weak self] rect in
                    let snapped = SelectionGeometry.snappedToPixels(rect, scale: scale, within: screenSize)
                    let region = ScreenRegion(displayID: displayID,
                                              quartzRect: ScreenCoordinates.quartzRect(fromView: snapped, screenQuartzFrame: quartzFrame),
                                              scale: scale)
                    self?.shoot(region) { .area($0, region) }
                },
                onPickWindow: { [weak self] info in
                    self?.resolve(.success(self?.windowsByID[info.id].map(Outcome.window) ?? .cancelled))
                },
                onPickFullScreen: { [weak self] in self?.shoot(wholeScreen) { .fullScreen($0, wholeScreen) } },
                onCancel: { [weak self] in self?.resolve(.success(.cancelled)) })
            panel.contentView = FirstMouseHostingView(rootView: view.themed(settings))
            panels.append(panel)
        }

        NSCursor.crosshair.push()
        for panel in panels {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        (panels.first { $0.frame.contains(mouse) } ?? panels.first)?.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.14
            for panel in panels { panel.animator().alphaValue = 1 }
        }, completionHandler: nil)
        // Fetched now, with the overlay on screen, so ClearShot is among the apps a shot leaves out.
        Task { contentUnderOverlay = try? await ScreenCapturer.content() }

        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    /// Pictures `region` as it is right now, through the overlay, and resolves with `outcome` of the picture.
    /// A second pick while one is being taken is ignored; Esc still cancels.
    private func shoot(_ region: ScreenRegion, outcome: @escaping (CGImage) -> Outcome) {
        guard continuation != nil, !isTakingShot else { return }
        isTakingShot = true
        Task {
            do {
                let content = if let contentUnderOverlay { contentUnderOverlay } else { try await ScreenCapturer.content() }
                let image = try await ScreenCapturer.captureRegion(region, in: content)
                resolve(.success(outcome(image)))
            } catch {
                resolve(.failure(error))
            }
        }
    }

    private func resolve(_ result: Result<Outcome, any Error>) {
        guard let continuation else { return }
        self.continuation = nil
        NSCursor.pop()
        let closing = panels
        panels.removeAll()
        // The caller goes on only once the overlay is gone. It sits above every window and takes every click, and
        // its fade stalls while an alert is modal: the scrolling capture's question could not be clicked.
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            for panel in closing { panel.animator().alphaValue = 0 }
        }, completionHandler: {
            MainActor.assumeIsolated {
                for panel in closing {
                    panel.orderOut(nil)
                    panel.contentView = nil
                }
                DiagnosticLog.write("capture overlay closed")
                continuation.resume(with: result)
            }
        })
    }
}

extension WindowInfo {
    init(_ window: SCWindow) {
        self.init(id: window.windowID, frame: window.frame, title: window.title,
                  ownerBundleID: window.owningApplication?.bundleIdentifier,
                  layer: window.windowLayer, isOnScreen: window.isOnScreen)
    }
}
