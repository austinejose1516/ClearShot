import CoreGraphics
import Foundation

public enum BlurMode: String, Equatable, Sendable, CaseIterable {
    case pixelate, blur
}

public enum HandleKind: Equatable, Sendable {
    case start, end, control, tail
    case topLeft, topRight, bottomLeft, bottomRight

    public var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomLeft, .bottomRight: true
        case .start, .end, .control, .tail: false
        }
    }
}

/// A dot the user can drag to reshape an annotation.
public struct Handle: Equatable, Sendable {
    public let kind: HandleKind
    public let point: CGPoint

    public init(_ kind: HandleKind, _ point: CGPoint) {
        self.kind = kind
        self.point = point
    }
}

/// What every annotation type knows about itself. Coordinates are image pixels.
/// Each type lives next to its data (`Figures.swift`, `TextContent.swift`); adding a type means one struct
/// and one case in `Annotation.Kind`.
public protocol Figure: Equatable, Sendable {
    var bounds: CGRect { get }
    var handles: [Handle] { get }
    var capabilities: StyleCapabilities { get }
    /// A drag this small was a click, not a drawing.
    var isTooSmall: Bool { get }
    /// The text the inline editor edits, if this type has any.
    var editableText: String? { get }
    func hitTest(_ point: CGPoint, tolerance: CGFloat, style: Annotation.Style) -> Bool
    /// Inside an outline shape (unfilled rectangle or ellipse). The pointer selects by clicking inside.
    func interiorContains(_ point: CGPoint) -> Bool
    mutating func move(by delta: CGVector)
    mutating func drag(_ handle: HandleKind, to point: CGPoint)
    /// This type's own part of a toolbar change (arrowhead, font size, …). Colour, width and fill live on the style.
    mutating func apply(_ change: StyleChange)
    /// Writes this type's own values into the toolbar values.
    func read(into values: inout StyleValues)
    mutating func setEditableText(_ text: String)
    var asKind: Annotation.Kind { get }
}

extension Figure {
    public var handles: [Handle] { [] }
    public var isTooSmall: Bool { max(bounds.width, bounds.height) < 3 }
    public var editableText: String? { nil }
    public func interiorContains(_ point: CGPoint) -> Bool { false }
    public mutating func drag(_ handle: HandleKind, to point: CGPoint) {}
    public mutating func apply(_ change: StyleChange) {}
    public func read(into values: inout StyleValues) {}
    public mutating func setEditableText(_ text: String) {}
}

/// One drawn thing: its figure, its style, and a stable id.
public struct Annotation: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case line(Line)
        case curve(Curve)
        case freehand(Freehand)
        case box(Box)
        case text(TextContent)
        case bubble(Bubble)
        case step(Step)
        case blur(Blur)

        /// The only switch over every type.
        public var figure: any Figure {
            switch self {
            case .line(let figure): figure
            case .curve(let figure): figure
            case .freehand(let figure): figure
            case .box(let figure): figure
            case .text(let figure): figure
            case .bubble(let figure): figure
            case .step(let figure): figure
            case .blur(let figure): figure
            }
        }

        /// Changes the figure in place; the figure puts itself back in the right case.
        public mutating func modify(_ change: (inout any Figure) -> Void) {
            var figure = self.figure
            change(&figure)
            self = figure.asKind
        }
    }

    public struct Style: Equatable, Sendable {
        public static let defaultWidth: CGFloat = 4

        public var strokeColor: RGBAColor
        public var strokeWidth: CGFloat
        public var fillColor: RGBAColor?

        public init(strokeColor: RGBAColor = .red, strokeWidth: CGFloat = defaultWidth, fillColor: RGBAColor? = nil) {
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

    public var bounds: CGRect { kind.figure.bounds }
    public var handles: [Handle] { kind.figure.handles }
    public var capabilities: StyleCapabilities { kind.figure.capabilities }
    public var isTooSmall: Bool { kind.figure.isTooSmall }
    public var editableText: String? { kind.figure.editableText }
    public var textContent: TextContent? {
        if case .text(let content) = kind { content } else { nil }
    }

    /// `includingInterior`: also inside unfilled rectangles and ellipses (the pointer tool).
    public func hitTest(_ point: CGPoint, tolerance: CGFloat, includingInterior: Bool = false) -> Bool {
        kind.figure.hitTest(point, tolerance: tolerance, style: style)
            || (includingInterior && kind.figure.interiorContains(point))
    }

    public mutating func move(by delta: CGVector) {
        kind.modify { $0.move(by: delta) }
    }

    public mutating func drag(_ handle: HandleKind, to point: CGPoint) {
        kind.modify { $0.drag(handle, to: point) }
    }

    public mutating func setEditableText(_ text: String) {
        kind.modify { $0.setEditableText(text) }
    }

    /// Applies one toolbar change, only where this annotation has that property.
    public mutating func apply(_ change: StyleChange) {
        let can = capabilities
        switch change {
        case .color(let color):
            guard can.contains(.color) else { return }
            style.strokeColor = color.withAlpha(style.strokeColor.alpha)
            if style.fillColor != nil { style.fillColor = style.strokeColor }
        case .opacity(let alpha):
            guard can.contains(.color) else { return }
            style.strokeColor = style.strokeColor.withAlpha(alpha)
            style.fillColor = style.fillColor?.withAlpha(alpha)
        case .width(let width):
            guard can.contains(.width) else { return }
            style.strokeWidth = width
        case .fill(let on):
            guard can.contains(.fill) else { return }
            style.fillColor = on ? style.strokeColor : nil
        case .arrow, .fontSize, .bold, .boxed, .blurMode, .stepSize, .cornerRadius:
            kind.modify { $0.apply(change) }
        }
    }
}
