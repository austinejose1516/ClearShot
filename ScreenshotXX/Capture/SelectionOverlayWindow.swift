import AppKit
import SwiftUI

/// Full-screen, borderless, above everything. A non-activating panel: it becomes key (so Esc works)
/// without activating the app, which macOS 14+ would refuse for a hotkey-woken background app.
final class SelectionOverlayWindow: NSPanel {
    var onCancel: (() -> Void)?
    var onToggleMode: (() -> Void)?

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onCancel?()        // Esc
        case 49: onToggleMode?()    // Space
        default: super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

/// Delivers the very first click as a real mouse-down (and so a drag), even when the app is not active.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
