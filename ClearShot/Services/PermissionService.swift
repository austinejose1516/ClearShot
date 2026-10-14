import AppKit
import AVFoundation
import CoreGraphics

enum PermissionService {
    static var hasScreenRecordingAccess: Bool { CGPreflightScreenCaptureAccess() }

    @discardableResult
    static func requestScreenRecordingAccess() -> Bool { CGRequestScreenCaptureAccess() }

    /// Asks the first time (the system sheet), then remembers. Recording goes on without the mic when refused.
    static func requestMicrophoneAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    static func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
