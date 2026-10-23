import CoreGraphics

/// Pure maths for the area-selection overlay. View coordinates are points with a top-left origin.
public enum SelectionGeometry {
    /// Anything smaller than this (in points) is a click, not a selection.
    public static let minimumSize: CGFloat = 3

    public static func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    public static func isUsable(_ rect: CGRect) -> Bool {
        rect.width >= minimumSize && rect.height >= minimumSize
    }

    /// `rect` grown to the whole pixels that cover it (a mouse position can sit between pixels on a Retina
    /// screen) and kept inside the screen, still in points. The pixels it names are then read straight off
    /// the screen, with nothing resampled.
    public static func snappedToPixels(_ rect: CGRect, scale: CGFloat, within size: CGSize) -> CGRect {
        guard scale > 0 else { return .zero }
        let pixels = CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
            .integral
            .intersection(CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale))
        return CGRect(x: pixels.minX / scale, y: pixels.minY / scale, width: pixels.width / scale, height: pixels.height / scale)
    }
}
