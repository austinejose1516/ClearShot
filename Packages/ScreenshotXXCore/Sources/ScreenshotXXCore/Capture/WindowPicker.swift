import CoreGraphics

public enum WindowPicker {
    /// Smaller windows are tooltips, popovers and other noise.
    public static let minimumSize: CGFloat = 50

    /// Real app windows only, in the order given (ScreenCaptureKit lists front to back).
    public static func candidates(_ windows: [WindowInfo], excludingBundleID own: String) -> [WindowInfo] {
        windows.filter { window in
            window.isOnScreen
                && window.layer == 0
                && window.ownerBundleID != own
                && window.frame.width >= minimumSize
                && window.frame.height >= minimumSize
        }
    }

    /// The front-most candidate under a Quartz point.
    public static func window(at point: CGPoint, in candidates: [WindowInfo]) -> WindowInfo? {
        candidates.first { $0.frame.contains(point) }
    }
}
