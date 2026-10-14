import CoreGraphics

/// AppKit puts the origin at the bottom-left of the primary display; Quartz (CGWindow, ScreenCaptureKit) at its top-left.
public enum ScreenCoordinates {
    public static func quartzPoint(fromAppKit point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    public static func quartzRect(fromAppKit rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// A Quartz rect expressed inside a view whose top-left corner is the screen's Quartz origin.
    public static func viewRect(fromQuartz rect: CGRect, screenQuartzFrame screen: CGRect) -> CGRect {
        rect.offsetBy(dx: -screen.minX, dy: -screen.minY)
    }

    /// The other way: a rect inside such a view, back to global Quartz coordinates.
    public static func quartzRect(fromView rect: CGRect, screenQuartzFrame screen: CGRect) -> CGRect {
        rect.offsetBy(dx: screen.minX, dy: screen.minY)
    }
}
