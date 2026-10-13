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

    /// Displays and on-screen windows (front to back) in one call.
    static func content() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }

    /// The display showing `screen`, or the first one.
    static func display(for screen: NSScreen?, in content: SCShareableContent) throws -> SCDisplay {
        if let match = content.displays.first(where: { $0.displayID == screen?.displayID }) { return match }
        guard let first = content.displays.first else { throw Failure.noDisplay }
        return first
    }

    /// Every NSScreen paired with its ScreenCaptureKit display.
    static func screenDisplays(in content: SCShareableContent) -> [(screen: NSScreen, display: SCDisplay)] {
        NSScreen.screens.compactMap { screen in
            guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) else { return nil }
            return (screen, display)
        }
    }

    static func captureWindow(_ window: SCWindow, showsCursor: Bool, includeShadow: Bool) async throws -> CGImage {
        let configuration = SCScreenshotConfiguration()
        configuration.showsCursor = showsCursor
        configuration.ignoreShadows = !includeShadow
        configuration.dynamicRange = .sdr
        return try await capture(SCContentFilter(desktopIndependentWindow: window), configuration)
    }

    static func captureDisplay(_ display: SCDisplay, showsCursor: Bool) async throws -> CGImage {
        let configuration = SCScreenshotConfiguration()
        configuration.showsCursor = showsCursor
        configuration.dynamicRange = .sdr
        return try await capture(SCContentFilter(display: display, excludingWindows: []), configuration)
    }

    private static func capture(_ filter: SCContentFilter, _ configuration: SCScreenshotConfiguration) async throws -> CGImage {
        let output = try await SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: configuration)
        guard let image = output.sdrImage else { throw Failure.noImage }
        return image
    }
}
