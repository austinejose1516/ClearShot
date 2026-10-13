import CoreGraphics
import Foundation

public enum BlurMode: String, Equatable, Sendable, Codable, CaseIterable {
    case pixelate, blur
}

/// One drawn thing. All coordinates are image pixels, so edits survive padding and inset changes.
public struct Annotation: Identifiable, Equatable, Sendable, Codable {
    public enum Kind: Equatable, Sendable, Codable {
        case line(start: CGPoint, end: CGPoint, arrowStart: Bool, arrowEnd: Bool)
        case freehand(points: [CGPoint])
        case rect(CGRect)
        case ellipse(CGRect)
        case curve(start: CGPoint, control: CGPoint, end: CGPoint, arrowEnd: Bool)
        case text(TextContent)
        /// Hides part of the base image.
        case blur(rect: CGRect, mode: BlurMode)
        /// Numbered circle for step-by-step guides.
        case step(number: Int, center: CGPoint, radius: CGFloat)
        case speechBubble(rect: CGRect, tail: CGPoint, text: String, fontSize: CGFloat)
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
        case .curve(let start, let control, let end, _):
            AnnotationGeometry.bounds(of: CurveGeometry.samples(start: start, control: control, end: end))
        case .text(let content): content.frame
        case .blur(let rect, _): rect.standardized
        case .step(_, let center, let radius):
            CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        case .speechBubble(let rect, let tail, _, _):
            rect.standardized.union(CGRect(origin: tail, size: .zero))
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
        case .curve(let start, let control, let end, _):
            let samples = CurveGeometry.samples(start: start, control: control, end: end)
            return zip(samples, samples.dropFirst()).contains { AnnotationGeometry.distance(from: point, toSegment: $0, $1) <= reach }
        case .text(let content):
            return content.frame.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        case .blur(let rect, _):
            return rect.standardized.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        case .step(_, let center, let radius):
            return hypot(point.x - center.x, point.y - center.y) <= radius + tolerance
        case .speechBubble(let rect, let tail, _, _):
            return rect.standardized.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
                || hypot(point.x - tail.x, point.y - tail.y) <= tolerance * 3
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
        case .curve(let start, let control, let end, let arrowEnd):
            kind = .curve(start: start.offset(delta), control: control.offset(delta), end: end.offset(delta), arrowEnd: arrowEnd)
        case .text(var content):
            content.origin = content.origin.offset(delta)
            kind = .text(content)
        case .blur(let rect, let mode):
            kind = .blur(rect: rect.offsetBy(dx: delta.dx, dy: delta.dy), mode: mode)
        case .step(let number, let center, let radius):
            kind = .step(number: number, center: center.offset(delta), radius: radius)
        case .speechBubble(let rect, let tail, let text, let fontSize):
            kind = .speechBubble(rect: rect.offsetBy(dx: delta.dx, dy: delta.dy), tail: tail.offset(delta), text: text, fontSize: fontSize)
        }
    }
}

extension CGPoint {
    func offset(_ delta: CGVector) -> CGPoint {
        CGPoint(x: x + delta.dx, y: y + delta.dy)
    }
}
