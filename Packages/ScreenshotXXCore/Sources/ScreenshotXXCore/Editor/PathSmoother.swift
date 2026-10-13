import CoreGraphics

/// Turns raw mouse points into a smooth curve (Catmull-Rom spline expressed as cubic Béziers).
public enum PathSmoother {
    public struct Segment: Equatable, Sendable {
        public let control1: CGPoint
        public let control2: CGPoint
        public let end: CGPoint
    }

    public static func segments(through points: [CGPoint]) -> (start: CGPoint, segments: [Segment])? {
        guard points.count >= 2 else { return nil }
        var segments: [Segment] = []
        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]
            let control1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let control2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            segments.append(Segment(control1: control1, control2: control2, end: p2))
        }
        return (points[0], segments)
    }
}
