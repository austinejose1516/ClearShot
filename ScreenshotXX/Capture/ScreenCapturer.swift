import AppKit
import ScreenCaptureKit

enum ScreenCapturer {
    enum Failure: LocalizedError {
        case noDisplay
        case noImage

        var errorDescription: String? {
            switch self {
            case .noDisplay: "No display found to capture."
            case .noImage: "The system returned no image."
            }
        }
    }

    /// The SCDisplay for the screen that contains `point` (AppKit screen coordinates). Falls back to the main display.
    static func display(under point: CGPoint) async throws -> SCDisplay {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let wantedID = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        if let match = content.displays.first(where: { $0.displayID == wantedID }) { return match }
        guard let first = content.displays.first else { throw Failure.noDisplay }
        return first
    }

    static func captureDisplay(_ display: SCDisplay, showsCursor: Bool) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCScreenshotConfiguration()
        configuration.showsCursor = showsCursor
        configuration.dynamicRange = .sdr
        let output = try await SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: configuration)
        guard let image = output.sdrImage else { throw Failure.noImage }
        return image
    }
}
