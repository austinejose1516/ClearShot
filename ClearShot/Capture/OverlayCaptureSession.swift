import AppKit
import ScreenCaptureKit
import ClearShotCore
import SwiftUI

/// One capture: freeze every screen, show an overlay on each, resolve on a drag, a window click or Esc.
@MainActor
final class OverlayCaptureSession {
    enum Mode {
        case area, window
    }

    enum Outcome {
        /// The cropped frozen image and where it sits on screen (recording and scrolling capture need the place).
        case area(CGImage, ScreenRegion)
        case window(SCWindow)
        case cancelled
    }

    private let state: OverlayState
    private var panels: [SelectionOverlayWindow] = []
    private var windowsByID: [UInt32: SCWindow] = [:]
    private var continuation: CheckedContinuation<Outcome, Never>?

    private init(mode: Mode) {
        state = OverlayState(mode: mode)
    }

    static func run(mode: Mode, settings: AppSettings) async throws -> Outcome {
        try await OverlayCaptureSession(mode: mode).start(settings: settings)
    }

    private func start(settings: AppSettings) async throws -> Outcome {
        let showsCursor = settings.showsCursor
        let content = try await ScreenCapturer.content()
        let pairs = ScreenCapturer.screenDisplays(in: content)
        guard !pairs.isEmpty else { throw ScreenCapturer.Failure.noDisplay }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        windowsByID = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
        state.windows = WindowPicker.candidates(
            content.windows.map(WindowInfo.init),
            excludingBundleID: Bundle.main.bundleIdentifier ?? "",
            screens: NSScreen.screens.map { ScreenCoordinates.quartzRect(fromAppKit: $0.frame, primaryHeight: primaryHeight) })

        // One display at a time: ScreenCaptureKit's display objects are not marked safe to share between tasks.
        var frozen: [(screen: NSScreen, image: CGImage)] = []
        for pair in pairs {
            frozen.append((pair.screen, try await ScreenCapturer.captureDisplay(pair.display, showsCursor: showsCursor)))
        }

        for (screen, image) in frozen {
            let panel = SelectionOverlayWindow(screen: screen)
            panel.onCancel = { [weak self] in self?.resolve(.cancelled) }
            panel.onToggleMode = { [state] in state.mode = state.mode == .area ? .window : .area }
            let quartzFrame = ScreenCoordinates.quartzRect(fromAppKit: screen.frame, primaryHeight: primaryHeight)
            let view = CaptureOverlayView(
                frozen: image,
                screenQuartzFrame: quartzFrame,
                state: state,
                onSelectArea: { [weak self] rect in
                    let pixelRect = SelectionGeometry.pixelRect(
                        viewRect: rect,
                        viewSize: screen.frame.size,
                        imageSize: CGSize(width: image.width, height: image.height))
                    let region = ScreenRegion(displayID: screen.displayID ?? 0,
                                              quartzRect: ScreenCoordinates.quartzRect(fromView: rect, screenQuartzFrame: quartzFrame),
                                              scale: screen.backingScaleFactor)
                    self?.resolve(image.cropping(to: pixelRect).map { .area($0, region) } ?? .cancelled)
                },
                onPickWindow: { [weak self] info in
                    self?.resolve(self?.windowsByID[info.id].map(Outcome.window) ?? .cancelled)
                },
                onCancel: { [weak self] in self?.resolve(.cancelled) })
            panel.contentView = FirstMouseHostingView(rootView: view.themed(settings))
            panels.append(panel)
        }

        NSCursor.crosshair.push()
        let mouse = NSEvent.mouseLocation
        for panel in panels {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        (panels.first { $0.frame.contains(mouse) } ?? panels.first)?.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.14
            for panel in panels { panel.animator().alphaValue = 1 }
        }, completionHandler: nil)

        return await withCheckedContinuation { continuation = $0 }
    }

    private func resolve(_ outcome: Outcome) {
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
                continuation.resume(returning: outcome)
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
