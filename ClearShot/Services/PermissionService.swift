import AppKit
import ApplicationServices
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

    /// Needed to scroll other apps for the scrolling capture.
    static var hasAccessibilityAccess: Bool { AXIsProcessTrusted() }

    /// Shows the system's own prompt the first time; later calls just answer.
    @discardableResult
    static func requestAccessibilityAccess() -> Bool {
        // The key behind kAXTrustedCheckOptionPrompt (a C global Swift 6 will not touch across isolation).
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    static func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    static func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
