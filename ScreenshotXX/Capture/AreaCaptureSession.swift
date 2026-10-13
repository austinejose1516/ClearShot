import AppKit
import ScreenCaptureKit
import ScreenshotXXCore
import SwiftUI

/// One area capture: freeze every screen, show an overlay on each, resolve on the first drag or Esc.
@MainActor
final class AreaCaptureSession {
    enum Outcome {
        case selected(CGImage)
        case cancelled
    }

    private var windows: [SelectionOverlayWindow] = []
    private var continuation: CheckedContinuation<Outcome, Never>?

    static func run(showsCursor: Bool) async throws -> Outcome {
        try await AreaCaptureSession().start(showsCursor: showsCursor)
    }

    private func start(showsCursor: Bool) async throws -> Outcome {
        let pairs = try await ScreenCapturer.screenDisplays()
        guard !pairs.isEmpty else { throw ScreenCapturer.Failure.noDisplay }

        var frozen: [(screen: NSScreen, image: CGImage)] = []
        for pair in pairs {
            let image = try await ScreenCapturer.captureDisplay(pair.display, showsCursor: showsCursor)
            frozen.append((pair.screen, image))
        }

        for (screen, image) in frozen {
            let window = SelectionOverlayWindow(screen: screen)
            window.onCancel = { [weak self] in self?.resolve(.cancelled) }
            let view = SelectionOverlayView(
                frozen: image,
                onSelect: { [weak self] rect in
                    let pixelRect = SelectionGeometry.pixelRect(
                        viewRect: rect,
                        viewSize: screen.frame.size,
                        imageSize: CGSize(width: image.width, height: image.height))
                    if let cropped = image.cropping(to: pixelRect) {
                        self?.resolve(.selected(cropped))
                    } else {
                        self?.resolve(.cancelled)
                    }
                },
                onCancel: { [weak self] in self?.resolve(.cancelled) })
            window.contentView = SelectionHostingView(rootView: view)
            windows.append(window)
        }

        NSCursor.crosshair.push()
        let mouse = NSEvent.mouseLocation
        for window in windows { window.orderFrontRegardless() }
        (windows.first { $0.frame.contains(mouse) } ?? windows.first)?.makeKeyAndOrderFront(nil)

        return await withCheckedContinuation { continuation = $0 }
    }

    private func resolve(_ outcome: Outcome) {
        guard let continuation else { return }
        self.continuation = nil
        NSCursor.pop()
        for window in windows {
            window.orderOut(nil)
            window.contentView = nil
        }
        windows.removeAll()
        continuation.resume(returning: outcome)
    }
}
