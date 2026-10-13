import CoreGraphics

public enum WindowPicker {
    /// Smaller windows are tooltips, popovers and other noise.
    public static let minimumSize: CGFloat = 50

    /// Real app windows only, in the order given (ScreenCaptureKit lists front to back).
    /// With `screens` (Quartz rects), windows that touch none of them are dropped too.
    public static func candidates(_ windows: [WindowInfo], excludingBundleID own: String, screens: [CGRect] = []) -> [WindowInfo] {
        windows.filter { window in
            window.isOnScreen
                && window.layer == 0
                && window.ownerBundleID != own
                && window.frame.width >= minimumSize
                && window.frame.height >= minimumSize
                && (screens.isEmpty || screens.contains { $0.intersects(window.frame) })
        }
    }

    /// The front-most candidate under a Quartz point.
    public static func window(at point: CGPoint, in candidates: [WindowInfo]) -> WindowInfo? {
        candidates.first { $0.frame.contains(point) }
    }
}
