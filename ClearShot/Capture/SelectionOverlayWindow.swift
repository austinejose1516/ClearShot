import AppKit
import ClearShotCore
import SwiftUI

/// Full-screen, borderless, above everything, see-through. A non-activating panel: it becomes key (so key
/// presses reach ClearShot) without activating the app, which macOS 14+ would refuse for a hotkey-woken
/// background app. The keys themselves (Esc, Space) are read by the session's event monitor.
final class SelectionOverlayWindow: NSPanel {
    /// The box being dragged on this screen. The panel tracks it itself (see `sendEvent`).
    let drag = AreaDrag()
    /// Whether a mouse-down starts a drag now (area mode) rather than going on to the view (a window or screen click).
    var startsDrag: () -> Bool = { false }
    /// Where the capture bar is, in view points; a click there is for the bar, not a drag.
    var barFrame: CGRect?
    /// The box when the mouse is let go; nil for a click.
    var onDragEnd: ((CGRect?) -> Void)?

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

    /// The area drag is tracked here, not by a SwiftUI gesture: that gesture holds key presses back until the
    /// mouse is let go, so Esc could not stop a drag. Everything else (hover, the bar, window and screen
    /// clicks) goes on to the view as usual.
    override func sendEvent(_ event: NSEvent) {
        let point = viewPoint(of: event)
        switch event.type {
        case .leftMouseDown where startsDrag() && !(barFrame?.contains(point) ?? false):
            drag.begin(at: point)
        case .leftMouseDragged where drag.isActive:
            drag.move(to: point)
        case .leftMouseUp where drag.isActive:
            onDragEnd?(drag.end(at: point))
        default:
            super.sendEvent(event)
        }
    }

    /// The event's place in view points (top-left origin, as SwiftUI sees them).
    private func viewPoint(of event: NSEvent) -> CGPoint {
        CGPoint(x: event.locationInWindow.x, y: frame.height - event.locationInWindow.y)
    }
}

/// Delivers the very first click as a real mouse-down (and so a drag), even when the app is not active.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
