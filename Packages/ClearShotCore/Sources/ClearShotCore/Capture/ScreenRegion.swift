import CoreGraphics

/// A rectangle on one display, in global Quartz points (top-left origin), plus that display's points-to-pixels scale.
public struct ScreenRegion: Equatable, Sendable {
    public let displayID: UInt32
    public let quartzRect: CGRect
    public let scale: CGFloat

    public init(displayID: UInt32, quartzRect: CGRect, scale: CGFloat) {
        self.displayID = displayID
        self.quartzRect = quartzRect
        self.scale = scale
    }

    /// The size in pixels, rounded to whole pixels.
    public var pixelSize: CGSize {
        CGSize(width: (quartzRect.width * scale).rounded(), height: (quartzRect.height * scale).rounded())
    }

    /// Where scroll events are posted.
    public var center: CGPoint {
        CGPoint(x: quartzRect.midX, y: quartzRect.midY)
    }

    /// The rect relative to its display's top-left corner (what ScreenCaptureKit's `sourceRect` wants).
    public func rect(inDisplay displayFrame: CGRect) -> CGRect {
        quartzRect.offsetBy(dx: -displayFrame.minX, dy: -displayFrame.minY)
    }
}
