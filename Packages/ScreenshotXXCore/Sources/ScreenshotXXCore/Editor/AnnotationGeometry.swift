import CoreGraphics

public enum AnnotationGeometry {
    public static func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        let closest = CGPoint(x: a.x + t * dx, y: a.y + t * dy)
        return hypot(p.x - closest.x, p.y - closest.y)
    }

    public static func distance(from p: CGPoint, toRectEdge rect: CGRect) -> CGFloat {
        let r = rect.standardized
        let corners = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                       CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)]
        return (0..<4).map { distance(from: p, toSegment: corners[$0], corners[($0 + 1) % 4]) }.min() ?? .infinity
    }

    /// Roughly how far `p` is from the outline of the ellipse inscribed in `rect`.
    public static func distance(from p: CGPoint, toEllipseEdge rect: CGRect) -> CGFloat {
        let r = rect.standardized
        let a = r.width / 2, b = r.height / 2
        guard a > 0, b > 0 else { return distance(from: p, toRectEdge: r) }
        let nx = (p.x - r.midX) / a, ny = (p.y - r.midY) / b
        return abs(hypot(nx, ny) - 1) * min(a, b)
    }

    public static func isInsideEllipse(_ p: CGPoint, _ rect: CGRect) -> Bool {
        let r = rect.standardized
        let a = r.width / 2, b = r.height / 2
        guard a > 0, b > 0 else { return false }
        let nx = (p.x - r.midX) / a, ny = (p.y - r.midY) / b
        return nx * nx + ny * ny <= 1
    }

    public static func bounds(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for p in points.dropFirst() {
            minX = min(minX, p.x); minY = min(minY, p.y)
            maxX = max(maxX, p.x); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

extension CGPoint {
    func offset(_ delta: CGVector) -> CGPoint {
        CGPoint(x: x + delta.dx, y: y + delta.dy)
    }
}
