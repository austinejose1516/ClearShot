import AppKit
import ScreenCaptureKit
import ScreenshotXXCore
import SwiftUI

/// One capture: freeze every screen, show an overlay on each, resolve on a drag, a window click or Esc.
@MainActor
final class OverlayCaptureSession {
    enum Mode {
        case area, window
    }

    enum Outcome {
        case area(CGImage)
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

    static func run(mode: Mode, showsCursor: Bool) async throws -> Outcome {
        try await OverlayCaptureSession(mode: mode).start(showsCursor: showsCursor)
    }

    private func start(showsCursor: Bool) async throws -> Outcome {
        let pairs = try await ScreenCapturer.screenDisplays()
        guard !pairs.isEmpty else { throw ScreenCapturer.Failure.noDisplay }

        let scWindows = try await ScreenCapturer.windows()
        windowsByID = Dictionary(scWindows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
        let primaryHeightForFilter = NSScreen.screens.first?.frame.height ?? 0
        let screenRects = NSScreen.screens.map { ScreenCoordinates.quartzRect(fromAppKit: $0.frame, primaryHeight: primaryHeightForFilter) }
        state.windows = WindowPicker.candidates(scWindows.map(WindowInfo.init),
                                                excludingBundleID: Bundle.main.bundleIdentifier ?? "",
                                                screens: screenRects)
        DiagnosticLog.write("windows front→back: " + state.windows.prefix(5).map { "\($0.title ?? "?") \($0.frame)" }.joined(separator: " | "))

        var frozen: [(screen: NSScreen, image: CGImage)] = []
        for pair in pairs {
            let image = try await ScreenCapturer.captureDisplay(pair.display, showsCursor: showsCursor)
            frozen.append((pair.screen, image))
        }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
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
                    if let cropped = image.cropping(to: pixelRect) {
                        self?.resolve(.area(cropped))
                    } else {
                        self?.resolve(.cancelled)
                    }
                },
                onPickWindow: { [weak self] info in
                    if let window = self?.windowsByID[info.id] {
                        self?.resolve(.window(window))
                    } else {
                        self?.resolve(.cancelled)
                    }
                },
                onCancel: { [weak self] in self?.resolve(.cancelled) })
            panel.contentView = FirstMouseHostingView(rootView: view)
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
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            for panel in closing { panel.animator().alphaValue = 0 }
        }, completionHandler: {
            MainActor.assumeIsolated {
                for panel in closing {
                    panel.orderOut(nil)
                    panel.contentView = nil
                }
            }
        })
        continuation.resume(returning: outcome)
    }
}

extension WindowInfo {
    init(_ window: SCWindow) {
        self.init(id: window.windowID, frame: window.frame, title: window.title,
                  ownerBundleID: window.owningApplication?.bundleIdentifier,
                  layer: window.windowLayer, isOnScreen: window.isOnScreen)
    }
}
