import CoreGraphics

public enum ArrowGeometry {
    /// The two wing points of an arrowhead whose tip is at `to`.
    public static func head(from: CGPoint, to: CGPoint, length: CGFloat, width: CGFloat) -> (left: CGPoint, right: CGPoint) {
        let dx = to.x - from.x, dy = to.y - from.y
        let distance = hypot(dx, dy)
        guard distance > 0 else { return (to, to) }
        let ux = dx / distance, uy = dy / distance
        let base = CGPoint(x: to.x - ux * length, y: to.y - uy * length)
        let nx = -uy * width / 2, ny = ux * width / 2
        return (CGPoint(x: base.x + nx, y: base.y + ny), CGPoint(x: base.x - nx, y: base.y - ny))
    }
}
