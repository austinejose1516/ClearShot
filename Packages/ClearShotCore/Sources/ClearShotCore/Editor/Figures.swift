import CoreGraphics
import CoreText

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

    /// The point `distance` before the end along the line (where an arrowhead's base sits).
    public func pointBefore(end distance: CGFloat) -> CGPoint {
        let total = hypot(end.x - start.x, end.y - start.y)
        guard total > 0 else { return start }
        let back = min(distance, total) / total
        return CGPoint(x: end.x - (end.x - start.x) * back, y: end.y - (end.y - start.y) * back)
    }
}

/// What the Arrow tool draws: a curved line (quadratic Bézier). It is drawn straight; its middle dot, which
/// sits on the curve, goes wherever it is dragged and the curve follows. With `arrow`, an arrowhead at the
/// end; with `bothEnds` as well, another at the start.
public struct Curve: Figure {
    public var start: CGPoint
    public var end: CGPoint
    /// Where the middle dot sits, measured from the midpoint of the straight line between the ends, in pixels:
    /// `bend` at right angles to that line (0 is straight; the sign picks the side) and `lean` along it (towards
    /// the end when positive). Both are kept when an end moves, so the shape turns with the line.
    public var bend: CGFloat
    public var lean: CGFloat
    public var arrow: Bool
    public var bothEnds: Bool

    public init(start: CGPoint, end: CGPoint, bend: CGFloat = 0, lean: CGFloat = 0, arrow: Bool, bothEnds: Bool = false) {
        self.start = start
        self.end = end
        self.bend = bend
        self.lean = lean
        self.arrow = arrow
        self.bothEnds = bothEnds
    }

    /// The same curve run the other way: the ends swap, and the middle dot stays where it is (the chord's
    /// directions flip, so `bend` and `lean` flip with them).
    public var reversed: Curve {
        Curve(start: end, end: start, bend: -bend, lean: -lean, arrow: arrow, bothEnds: bothEnds)
    }

    /// The straight line between the ends: its midpoint, a unit vector along it and one at right angles to it.
    private var chord: (mid: CGPoint, along: CGVector, across: CGVector) {
        let dx = end.x - start.x, dy = end.y - start.y
        let length = hypot(dx, dy)
        let along = length > 0 ? CGVector(dx: dx / length, dy: dy / length) : .zero
        return (CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2), along, CGVector(dx: -along.dy, dy: along.dx))
    }

    /// The point `factor` times the bend and lean away from the chord's midpoint.
    private func offChord(_ factor: CGFloat) -> CGPoint {
        let (mid, along, across) = chord
        return CGPoint(x: mid.x + (along.dx * lean + across.dx * bend) * factor,
                       y: mid.y + (along.dy * lean + across.dy * bend) * factor)
    }

    /// The point on the curve halfway along: where the middle dot sits.
    public var middle: CGPoint { offChord(1) }

    /// The Bézier control point. The curve's midpoint is ¼ start + ½ control + ¼ end, so the control sits twice
    /// as far out as the middle dot.
    public var control: CGPoint { offChord(2) }

    private var samples: [CGPoint] { CurveGeometry.samples(start: start, control: control, end: end) }

    public var bounds: CGRect { AnnotationGeometry.bounds(of: samples) }
    public var handles: [Handle] { [Handle(.start, start), Handle(.middle, middle), Handle(.end, end)] }
    public var capabilities: StyleCapabilities { [.color, .width, .arrow, .bothEnds] }
    public var asKind: Annotation.Kind { .curve(self) }

    public func hitTest(_ point: CGPoint, tolerance: CGFloat, style: Annotation.Style) -> Bool {
        let reach = tolerance + style.strokeWidth / 2
        return zip(samples, samples.dropFirst()).contains { AnnotationGeometry.distance(from: point, toSegment: $0, $1) <= reach }
    }

    public mutating func move(by delta: CGVector) {
        start = start.offset(delta)
        end = end.offset(delta)
    }

    public mutating func drag(_ handle: HandleKind, to point: CGPoint) {
        switch handle {
        case .start: start = point
        case .end: end = point
        case .middle:
            // The dot lands exactly under the pointer, split into its along and across parts.
            let (mid, along, across) = chord
            lean = (point.x - mid.x) * along.dx + (point.y - mid.y) * along.dy
            bend = (point.x - mid.x) * across.dx + (point.y - mid.y) * across.dy
        default: break
        }
    }

    public mutating func apply(_ change: StyleChange) {
        switch change {
        case .arrow(let on): arrow = on
        case .bothEnds(let on): bothEnds = on
        default: break
        }
    }

    public func read(into values: inout StyleValues) {
        values.arrow = arrow
        values.bothEnds = bothEnds
    }

    /// The point about `distance` after the start, measured along the curve, and its curve parameter: where
    /// the start head's base sits when the arrow has both ends.
    public func pointAfter(start distance: CGFloat) -> (point: CGPoint, t: CGFloat) {
        let fromTheOtherEnd = reversed.pointBefore(end: distance)
        return (fromTheOtherEnd.point, 1 - fromTheOtherEnd.t)
    }

    /// The point about `distance` before the end, measured along the curve, and its curve parameter.
    /// An arrowhead's base sits here, so the curve flows into the middle of the head.
    public func pointBefore(end distance: CGFloat) -> (point: CGPoint, t: CGFloat) {
        let steps = 96
        var previous = end
        var travelled: CGFloat = 0
        for index in stride(from: steps - 1, through: 0, by: -1) {
            let t = CGFloat(index) / CGFloat(steps)
            let point = CurveGeometry.point(start: start, control: control, end: end, t: t)
            let step = hypot(point.x - previous.x, point.y - previous.y)
            if travelled + step >= distance {
                let fraction = step > 0 ? (distance - travelled) / step : 0
                let at = CGFloat(index + 1) / CGFloat(steps) - fraction / CGFloat(steps)
                return (CurveGeometry.point(start: start, control: control, end: end, t: at), at)
            }
            travelled += step
            previous = point
        }
        return (start, 0)
    }

    /// The piece of this curve between parameters `t0` and `t1`, as plain Bézier points: the piece is not
    /// symmetric, so it is not a `Curve`. Its control point blends the three points by both parameters (the
    /// Bézier "blossom"), which is the de Casteljau split done at both ends at once.
    public func segment(from t0: CGFloat, to t1: CGFloat) -> (start: CGPoint, control: CGPoint, end: CGPoint) {
        let t0 = max(0, min(1, t0)), t1 = max(0, min(1, t1))
        let control = control
        let weights = (start: (1 - t0) * (1 - t1), control: (1 - t0) * t1 + t0 * (1 - t1), end: t0 * t1)
        return (CurveGeometry.point(start: start, control: control, end: end, t: t0),
                CGPoint(x: weights.start * start.x + weights.control * control.x + weights.end * end.x,
                        y: weights.start * start.y + weights.control * control.y + weights.end * end.y),
                CurveGeometry.point(start: start, control: control, end: end, t: t1))
    }
}

/// A pen stroke, or a highlighter stroke: the same points, drawn wide and see-through over the image.
public struct Freehand: Figure {
    public enum Form: Equatable, Sendable {
        case pen, highlighter
    }

    public var points: [CGPoint]
    public var form: Form

    public init(points: [CGPoint], form: Form = .pen) {
        self.points = points
        self.form = form
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

/// A rectangle (optionally with rounded corners) or an ellipse, optionally filled.
public struct Box: Figure {
    public enum Form: Equatable, Sendable {
        case rectangle, ellipse
    }

    public var rect: CGRect
    public var form: Form
    public var cornerRadius: CGFloat

    public init(rect: CGRect, form: Form, cornerRadius: CGFloat = 0) {
        self.rect = rect
        self.form = form
        self.cornerRadius = cornerRadius
    }

    public var bounds: CGRect { rect.standardized }
    public var handles: [Handle] { rect.cornerHandles }
    public var capabilities: StyleCapabilities {
        form == .rectangle ? [.color, .width, .fill, .corners] : [.color, .width, .fill]
    }
    public var asKind: Annotation.Kind { .box(self) }

    public func interiorContains(_ point: CGPoint) -> Bool {
        form == .rectangle ? rect.standardized.contains(point) : AnnotationGeometry.isInsideEllipse(point, rect)
    }

    public mutating func apply(_ change: StyleChange) {
        if case .cornerRadius(let radius) = change, form == .rectangle { cornerRadius = radius }
    }

    public func read(into values: inout StyleValues) {
        if form == .rectangle { values.cornerRadius = cornerRadius }
    }

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

    public init(rect: CGRect, tail: CGPoint, text: String = "", fontSize: CGFloat = 32) {
        self.rect = rect
        self.tail = tail
        self.text = text
        self.fontSize = fontSize
    }

    /// A new bubble from a drag: tail below-left, the toolbar's font size (shrunk to fit when needed).
    public static func drawn(from start: CGPoint, to end: CGPoint, fontSize: CGFloat) -> Bubble {
        let r = SelectionGeometry.normalizedRect(from: start, to: end)
        return Bubble(rect: r, tail: CGPoint(x: r.minX + r.width * 0.25, y: r.maxY + r.height * 0.5), fontSize: fontSize)
    }

    /// The same family as text annotations, a step bolder so short words stand out in the box.
    /// Drawn at `fittedFontSize`, so long text shrinks instead of spilling out of the bubble.
    public var font: CTFont { Self.font(size: fittedFontSize) }

    /// `fontSize`, or the largest smaller size at which the wrapped text fits in `textRect`.
    public var fittedFontSize: CGFloat {
        let box = textRect
        // SwiftUI's Text and the inline editor's text view can wrap a word earlier than CoreText measures,
        // so fit to a slightly narrower box: the text stays inside the bubble in both.
        func fits(_ size: CGFloat) -> Bool {
            TextMetrics.size(of: text, font: Self.font(size: size), width: box.width - 10).height <= box.height
        }
        guard !text.isEmpty, !fits(fontSize) else { return fontSize }
        var low = TextContent.minimumFontSize, high = fontSize
        while high - low > 0.5 {
            let middle = (low + high) / 2
            if fits(middle) { low = middle } else { high = middle }
        }
        return low
    }

    private static func font(size: CGFloat) -> CTFont { TextMetrics.avenirNext("DemiBold", size: size) }

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
