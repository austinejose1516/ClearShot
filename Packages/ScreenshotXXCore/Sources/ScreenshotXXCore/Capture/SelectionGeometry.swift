import CoreGraphics

/// Pure maths for the area-selection overlay. View coordinates are points with a top-left origin,
/// exactly like the frozen screen image, so one scale factor maps between them.
public enum SelectionGeometry {
    /// Anything smaller than this (in points) is a click, not a selection.
    public static let minimumSize: CGFloat = 3

    public static func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    public static func isUsable(_ rect: CGRect) -> Bool {
        rect.width >= minimumSize && rect.height >= minimumSize
    }

    /// Whole-pixel rect inside `imageSize` that covers `viewRect`.
    public static func pixelRect(viewRect: CGRect, viewSize: CGSize, imageSize: CGSize) -> CGRect {
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }
        let scale = imageSize.width / viewSize.width
        let scaled = CGRect(x: viewRect.minX * scale, y: viewRect.minY * scale,
                            width: viewRect.width * scale, height: viewRect.height * scale)
        let bounds = CGRect(origin: .zero, size: imageSize)
        return scaled.integral.intersection(bounds)
    }
}
