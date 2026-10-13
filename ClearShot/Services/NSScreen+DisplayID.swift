import AppKit

extension NSScreen {
    /// The CoreGraphics display id, which ScreenCaptureKit uses too.
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// The screen under the mouse, falling back to the main screen.
    static var underMouse: NSScreen? {
        let mouse = NSEvent.mouseLocation
        return screens.first { $0.frame.contains(mouse) } ?? main
    }
}
