import AppKit
import ClearShotCore
import ScreenCaptureKit

/// Picks what a recording or a scrolling capture covers: an area, a window or a whole screen. Nil when the
/// person cancels.
@MainActor
enum RegionPicker {
    /// Where the pick is on screen, and the window itself when a window was picked: a recording uses its spot,
    /// a scrolling capture pictures the window alone (so what shows through a see-through window stays out).
    struct Target {
        let region: ScreenRegion
        let window: SCWindow?
    }

    static func pick(_ kind: CaptureKind, settings: AppSettings) async throws -> Target? {
        switch kind {
        case .fullScreen:
            let content = try await ScreenCapturer.content()
            let screen = NSScreen.underMouse
            let display = try ScreenCapturer.display(for: screen, in: content)
            return Target(region: ScreenRegion(displayID: display.displayID, quartzRect: display.frame, scale: screen?.backingScaleFactor ?? 2),
                          window: nil)
        case .area, .window, .scrolling:
            switch try await OverlayCaptureSession.run(mode: kind == .window ? .window : .area, settings: settings) {
            case .area(_, let region): return Target(region: region, window: nil)
            case .window(let window): return Target(region: try await spot(of: window), window: window)
            case .cancelled: return nil
            }
        }
    }

    /// A window is used as its spot on screen (inside its display), so ClearShot's own drawing there (the click
    /// rings) is in the picture too. Its app comes to the front, so nothing covers it.
    private static func spot(of window: SCWindow) async throws -> ScreenRegion {
        let content = try await ScreenCapturer.content()
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        guard let display = content.displays.first(where: { $0.frame.contains(center) }) ?? content.displays.first else {
            throw ScreenCapturer.Failure.noDisplay
        }
        if let pid = window.owningApplication?.processID {
            NSRunningApplication(processIdentifier: pid)?.activate()
        }
        let scale = NSScreen.screens.first { $0.displayID == display.displayID }?.backingScaleFactor ?? 2
        return ScreenRegion(displayID: display.displayID, quartzRect: window.frame.intersection(display.frame).integral, scale: scale)
    }
}

extension ScreenRegion {
    var screen: NSScreen? {
        NSScreen.screens.first { $0.displayID == displayID }
    }

    /// The region in AppKit coordinates (origin bottom-left of the main screen).
    var appKitRect: CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: quartzRect.minX, y: primaryHeight - quartzRect.maxY, width: quartzRect.width, height: quartzRect.height)
    }

    /// The whole of its screen (Full Screen): no frame is drawn around it.
    var coversWholeScreen: Bool {
        guard let screen else { return false }
        return abs(appKitRect.width - screen.frame.width) < 1 && abs(appKitRect.height - screen.frame.height) < 1
    }
}
