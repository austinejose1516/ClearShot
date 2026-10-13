import CoreGraphics

/// A straight line; with `arrow`, an arrowhead at the end.
public struct Line: Figure {
    public var start: CGPoint
    public var end: CGPoint
    public var arrow: Bool

    public init(start: CGPoint, end: CGPoint, arrow: Bool = false) {
        self.start = start
        self.end = end
        self.arrow = arrow
    }

    public var bounds: CGRect { AnnotationGeometry.bounds(of: [start, end]) }
    public var handles: [Handle] { [Handle(.start, start), Handle(.end, end)] }
    public var capabilities: StyleCapabilities { [.color, .width, .arrow] }
    public var asKind: Annotation.Kind { .line(self) }

    public func hitTest(_ point: CGPoint, tolerance: CGFloat, style: Annotation.Style) -> Bool {
        AnnotationGeometry.distance(from: point, toSegment: start, end) <= tolerance + style.strokeWidth / 2
    }

    public mutating func move(by delta: CGVector) {
        start = start.offset(delta)
        end = end.offset(delta)
    }

    public mutating func drag(_ handle: HandleKind, to point: CGPoint) {
        if handle == .start { start = point }
        if handle == .end { end = point }
    }

    public mutating func apply(_ change: StyleChange) {
        if case .arrow(let on) = change { arrow = on }
    }

    public func read(into values: inout StyleValues) { values.arrow = arrow }
}

/// A curved line (quadratic Bézier); the middle handle bends it.
public struct Curve: Figure {
    public var start: CGPoint
    public var control: CGPoint
    public var end: CGPoint
    public var arrow: Bool

    public init(start: CGPoint, control: CGPoint, end: CGPoint, arrow: Bool) {
        self.start = start
        self.control = control
        self.end = end
        self.arrow = arrow
    }

    /// A new curve from a drag, bent by a quarter of its length so it looks curved right away.
    public static func bent(from start: CGPoint, to end: CGPoint, arrow: Bool) -> Curve {
        let dx = end.x - start.x, dy = end.y - start.y
        let control = CGPoint(x: (start.x + end.x) / 2 - dy * 0.25, y: (start.y + end.y) / 2 + dx * 0.25)
        return Curve(start: start, control: control, end: end, arrow: arrow)
    }

    private var samples: [CGPoint] { CurveGeometry.samples(start: start, control: control, end: end) }

    public var bounds: CGRect { AnnotationGeometry.bounds(of: samples) }
    public var handles: [Handle] { [Handle(.start, start), Handle(.control, control), Handle(.end, end)] }
    public var capabilities: StyleCapabilities { [.color, .width, .arrow] }
    public var asKind: Annotation.Kind { .curve(self) }

    public func hitTest(_ point: CGPoint, tolerance: CGFloat, style: Annotation.Style) -> Bool {
        let reach = tolerance + style.strokeWidth / 2
        return zip(samples, samples.dropFirst()).contains { AnnotationGeometry.distance(from: point, toSegment: $0, $1) <= reach }
    }

    public mutating func move(by delta: CGVector) {
        start = start.offset(delta)
        control = control.offset(delta)
        end = end.offset(delta)
    }

    public mutating func drag(_ handle: HandleKind, to point: CGPoint) {
        switch handle {
        case .start: start = point
        case .control: control = point
        case .end: end = point
        default: break
        }
    }

    public mutating func apply(_ change: StyleChange) {
        if case .arrow(let on) = change { arrow = on }
    }

    public func read(into values: inout StyleValues) { values.arrow = arrow }
}

/// A pen stroke.
public struct Freehand: Figure {
    public var points: [CGPoint]

    public init(points: [CGPoint]) {
        self.points = points
    }

    public var bounds: CGRect { AnnotationGeometry.bounds(of: points) }
    public var capabilities: StyleCapabilities { [.color, .width] }
    public var isTooSmall: Bool { points.count < 2 }
    public var asKind: Annotation.Kind { .freehand(self) }

    public func hitTest(_ point: CGPoint, tolerance: CGFloat, style: Annotation.Style) -> Bool {
        let reach = tolerance + style.strokeWidth / 2
        guard points.count > 1 else {
            return points.first.map { hypot($0.x - point.x, $0.y - point.y) <= reach } ?? false
        }
        return zip(points, points.dropFirst()).contains { AnnotationGeometry.distance(from: point, toSegment: $0, $1) <= reach }
    }

    public mutating func move(by delta: CGVector) {
        points = points.map { $0.offset(delta) }
    }
}

/// A rectangle or an ellipse, optionally filled.
public struct Box: Figure {
    public enum Form: Equatable, Sendable {
        case rectangle, ellipse
    }

    public var rect: CGRect
    public var form: Form

    public init(rect: CGRect, form: Form) {
        self.rect = rect
        self.form = form
    }

    public var bounds: CGRect { rect.standardized }
    public var handles: [Handle] { rect.cornerHandles }
    public var capabilities: StyleCapabilities { [.color, .width, .fill] }
    public var asKind: Annotation.Kind { .box(self) }

    public func hitTest(_ point: CGPoint, tolerance: CGFloat, style: Annotation.Style) -> Bool {
        let reach = tolerance + style.strokeWidth / 2
        switch form {
        case .rectangle:
            if style.fillColor != nil, rect.standardized.contains(point) { return true }
            return AnnotationGeometry.distance(from: point, toRectEdge: rect) <= reach
        case .ellipse:
            if style.fillColor != nil, AnnotationGeometry.isInsideEllipse(point, rect) { return true }
            return AnnotationGeometry.distance(from: point, toEllipseEdge: rect) <= reach
        }
    }

    public mutating func move(by delta: CGVector) {
        rect = rect.offsetBy(dx: delta.dx, dy: delta.dy)
    }

    public mutating func drag(_ handle: HandleKind, to point: CGPoint) {
        rect = rect.resized(dragging: handle, to: point)
    }
}

/// A speech bubble: rounded box, text inside, and a tail pointing somewhere.
public struct Bubble: Figure {
    public var rect: CGRect
    public var tail: CGPoint
    public var text: String
    public var fontSize: CGFloat

    public init(rect: CGRect, tail: CGPoint, text: String = "", fontSize: CGFloat = 28) {
        self.rect = rect
        self.tail = tail
        self.text = text
        self.fontSize = fontSize
    }

    /// A new bubble from a drag: tail below-left, font size from the height.
    public static func drawn(from start: CGPoint, to end: CGPoint) -> Bubble {
        let r = SelectionGeometry.normalizedRect(from: start, to: end)
        return Bubble(rect: r,
                      tail: CGPoint(x: r.minX + r.width * 0.25, y: r.maxY + r.height * 0.5),
                      fontSize: max(20, (r.height / 4).rounded()))
    }

    /// Where the text goes inside the box.
    public var textRect: CGRect {
        let r = rect.standardized
        return CGRect(x: r.minX + fontSize * 0.4, y: r.minY + fontSize * 0.3,
                      width: max(1, r.width - fontSize * 0.8), height: max(1, r.height - fontSize * 0.6))
    }

    public var bounds: CGRect { rect.standardized.union(CGRect(origin: tail, size: .zero)) }
    public var handles: [Handle] { rect.cornerHandles + [Handle(.tail, tail)] }
    public var capabilities: StyleCapabilities { [.color, .width, .fontSize] }
    public var isTooSmall: Bool { max(rect.width, rect.height) < 3 }
    public var editableText: String? { text }
    public var asKind: Annotation.Kind { .bubble(self) }

    public func hitTest(_ point: CGPoint, tolerance: CGFloat, style: Annotation.Style) -> Bool {
        rect.standardized.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
            || hypot(point.x - tail.x, point.y - tail.y) <= tolerance * 3
    }

    public mutating func move(by delta: CGVector) {
        rect = rect.offsetBy(dx: delta.dx, dy: delta.dy)
        tail = tail.offset(delta)
    }

    public mutating func drag(_ handle: HandleKind, to point: CGPoint) {
        if handle == .tail { tail = point } else { rect = rect.resized(dragging: handle, to: point) }
    }

    public mutating func apply(_ change: StyleChange) {
        if case .fontSize(let size) = change { fontSize = size }
    }

    public func read(into values: inout StyleValues) { values.fontSize = fontSize }

    public mutating func setEditableText(_ text: String) { self.text = text }
}

/// A numbered circle for step-by-step guides. Corner dots resize it around its centre.
public struct Step: Figure {
    public static let minimumRadius: CGFloat = 10

    public var number: Int
    public var center: CGPoint
    public var radius: CGFloat

    public init(number: Int, center: CGPoint, radius: CGFloat) {
        self.number = number
        self.center = center
        self.radius = radius
    }

    public var bounds: CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    public var handles: [Handle] { bounds.cornerHandles }
    public var capabilities: StyleCapabilities { [.color, .stepSize] }
    public var asKind: Annotation.Kind { .step(self) }

    public func hitTest(_ point: CGPoint, tolerance: CGFloat, style: Annotation.Style) -> Bool {
        hypot(point.x - center.x, point.y - center.y) <= radius + tolerance
    }

    public mutating func move(by delta: CGVector) {
        center = center.offset(delta)
    }

    public mutating func drag(_ handle: HandleKind, to point: CGPoint) {
        guard handle.isCorner else { return }
        radius = max(Self.minimumRadius, max(abs(point.x - center.x), abs(point.y - center.y)))
    }

    public mutating func apply(_ change: StyleChange) {
        if case .stepSize(let size) = change { radius = size }
    }

    public func read(into values: inout StyleValues) { values.stepRadius = radius }
}

/// Hides part of the base image, pixelated or blurred.
public struct Blur: Figure {
    public var rect: CGRect
    public var mode: BlurMode

    public init(rect: CGRect, mode: BlurMode) {
        self.rect = rect
        self.mode = mode
    }

    public var bounds: CGRect { rect.standardized }
    public var handles: [Handle] { rect.cornerHandles }
    public var capabilities: StyleCapabilities { [.blurMode] }
    public var asKind: Annotation.Kind { .blur(self) }

    public func hitTest(_ point: CGPoint, tolerance: CGFloat, style: Annotation.Style) -> Bool {
        rect.standardized.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
    }

    public mutating func move(by delta: CGVector) {
        rect = rect.offsetBy(dx: delta.dx, dy: delta.dy)
    }

    public mutating func drag(_ handle: HandleKind, to point: CGPoint) {
        rect = rect.resized(dragging: handle, to: point)
    }

    public mutating func apply(_ change: StyleChange) {
        if case .blurMode(let mode) = change { self.mode = mode }
    }

    public func read(into values: inout StyleValues) { values.blurMode = mode }
}

extension CGRect {
    /// Corner handles: top-left, top-right, bottom-left, bottom-right.
    var cornerHandles: [Handle] {
        let b = standardized
        return [Handle(.topLeft, CGPoint(x: b.minX, y: b.minY)), Handle(.topRight, CGPoint(x: b.maxX, y: b.minY)),
                Handle(.bottomLeft, CGPoint(x: b.minX, y: b.maxY)), Handle(.bottomRight, CGPoint(x: b.maxX, y: b.maxY))]
    }

    /// The corner that stays put while `corner` is dragged.
    func anchor(opposite corner: HandleKind) -> CGPoint? {
        let b = standardized
        switch corner {
        case .topLeft: return CGPoint(x: b.maxX, y: b.maxY)
        case .topRight: return CGPoint(x: b.minX, y: b.maxY)
        case .bottomLeft: return CGPoint(x: b.maxX, y: b.minY)
        case .bottomRight: return CGPoint(x: b.minX, y: b.minY)
        default: return nil
        }
    }

    /// This rect after dragging one corner to `point`; the opposite corner stays.
    func resized(dragging corner: HandleKind, to point: CGPoint) -> CGRect {
        guard let anchor = anchor(opposite: corner) else { return standardized }
        return SelectionGeometry.normalizedRect(from: anchor, to: point)
    }
}
