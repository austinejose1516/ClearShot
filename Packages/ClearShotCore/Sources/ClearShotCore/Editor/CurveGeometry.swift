import CoreGraphics

/// Quadratic Bézier helpers for the curved line tool.
public enum CurveGeometry {
    public static func point(start: CGPoint, control: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
                       y: u * u * start.y + 2 * u * t * control.y + t * t * end.y)
    }

    /// `count` segments → `count + 1` points, from start to end.
    public static func samples(start: CGPoint, control: CGPoint, end: CGPoint, count: Int = 24) -> [CGPoint] {
        (0...max(1, count)).map { point(start: start, control: control, end: end, t: CGFloat($0) / CGFloat(max(1, count))) }
    }
}
