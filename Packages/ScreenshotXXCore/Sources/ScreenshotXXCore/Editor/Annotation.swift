import CoreGraphics
import Foundation

/// One drawn thing. All coordinates are image pixels, so edits survive padding and inset changes.
public struct Annotation: Identifiable, Equatable, Sendable, Codable {
    public enum Kind: Equatable, Sendable, Codable {
        case line(start: CGPoint, end: CGPoint, arrowStart: Bool, arrowEnd: Bool)
        case freehand(points: [CGPoint])
        case rect(CGRect)
        case ellipse(CGRect)
    }

    public struct Style: Equatable, Sendable, Codable {
        public var strokeColor: RGBAColor
        public var strokeWidth: CGFloat
        public var fillColor: RGBAColor?

        public init(strokeColor: RGBAColor = .red, strokeWidth: CGFloat = 6, fillColor: RGBAColor? = nil) {
            self.strokeColor = strokeColor
            self.strokeWidth = strokeWidth
            self.fillColor = fillColor
        }
    }

    public let id: UUID
    public var kind: Kind
    public var style: Style

    public init(kind: Kind, style: Style = Style()) {
        self.id = UUID()
        self.kind = kind
        self.style = style
    }

    /// Geometric bounds, without the stroke.
    public var bounds: CGRect {
        switch kind {
        case .line(let start, let end, _, _): AnnotationGeometry.bounds(of: [start, end])
        case .freehand(let points): AnnotationGeometry.bounds(of: points)
        case .rect(let rect), .ellipse(let rect): rect.standardized
        }
    }

    public func hitTest(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        let reach = tolerance + style.strokeWidth / 2
        switch kind {
        case .line(let start, let end, _, _):
            return AnnotationGeometry.distance(from: point, toSegment: start, end) <= reach
        case .freehand(let points):
            guard points.count > 1 else {
                return points.first.map { hypot($0.x - point.x, $0.y - point.y) <= reach } ?? false
            }
            return zip(points, points.dropFirst()).contains { AnnotationGeometry.distance(from: point, toSegment: $0, $1) <= reach }
        case .rect(let rect):
            if style.fillColor != nil, rect.standardized.contains(point) { return true }
            return AnnotationGeometry.distance(from: point, toRectEdge: rect) <= reach
        case .ellipse(let rect):
            if style.fillColor != nil, AnnotationGeometry.isInsideEllipse(point, rect) { return true }
            return AnnotationGeometry.distance(from: point, toEllipseEdge: rect) <= reach
        }
    }

    public mutating func move(by delta: CGVector) {
        switch kind {
        case .line(let start, let end, let arrowStart, let arrowEnd):
            kind = .line(start: start.offset(delta), end: end.offset(delta), arrowStart: arrowStart, arrowEnd: arrowEnd)
        case .freehand(let points):
            kind = .freehand(points: points.map { $0.offset(delta) })
        case .rect(let rect):
            kind = .rect(rect.offsetBy(dx: delta.dx, dy: delta.dy))
        case .ellipse(let rect):
            kind = .ellipse(rect.offsetBy(dx: delta.dx, dy: delta.dy))
        }
    }
}

extension CGPoint {
    func offset(_ delta: CGVector) -> CGPoint {
        CGPoint(x: x + delta.dx, y: y + delta.dy)
    }
}
