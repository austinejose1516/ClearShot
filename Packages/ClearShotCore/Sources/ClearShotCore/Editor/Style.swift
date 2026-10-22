import CoreGraphics

/// Which toolbar controls make sense for an annotation type or a tool.
public struct StyleCapabilities: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Colour and opacity.
    public static let color = StyleCapabilities(rawValue: 1 << 0)
    /// Line thickness: lines, arrows, curves, pen, rectangles, ellipses and the bubble border.
    public static let width = StyleCapabilities(rawValue: 1 << 1)
    public static let fill = StyleCapabilities(rawValue: 1 << 2)
    public static let arrow = StyleCapabilities(rawValue: 1 << 3)
    public static let fontSize = StyleCapabilities(rawValue: 1 << 4)
    /// Bold, italic, underline and boxed.
    public static let textStyle = StyleCapabilities(rawValue: 1 << 5)
    public static let blurMode = StyleCapabilities(rawValue: 1 << 6)
    public static let stepSize = StyleCapabilities(rawValue: 1 << 7)
    /// Rounded corners (rectangles).
    public static let corners = StyleCapabilities(rawValue: 1 << 8)
    /// A second arrowhead, at the start (arrows).
    public static let bothEnds = StyleCapabilities(rawValue: 1 << 9)
}

/// One change made in the toolbar.
public enum StyleChange: Equatable, Sendable {
    case color(RGBAColor)
    case opacity(Double)
    case width(CGFloat)
    case fill(Bool)
    case arrow(Bool)
    case bothEnds(Bool)
    case fontSize(CGFloat)
    case bold(Bool)
    case italic(Bool)
    case underline(Bool)
    case boxed(Bool)
    case blurMode(BlurMode)
    case stepSize(CGFloat)
    case cornerRadius(CGFloat)
}

/// The toolbar's values: what new annotations get, and what the toolbar shows for a selection.
public struct StyleValues: Equatable, Sendable {
    public static let widthRange: ClosedRange<CGFloat> = 1...40
    public static let opacities: [Double] = [1, 0.75, 0.5, 0.25]
    public static let fontSizes: [CGFloat] = [12, 14, 16, 18, 20, 24, 28, 32, 36, 40, 48, 56, 64, 72, 96, 128]
    /// Radii; the toolbar shows diameters (40 px … 192 px).
    public static let stepSizes: [CGFloat] = [20, 28, 36, 48, 64, 96]
    public static let cornerRadii: [CGFloat] = [0, 8, 16, 24, 40]

    public var color: RGBAColor = .red
    public var opacity: Double = 1
    public var width: CGFloat = Annotation.Style.defaultWidth
    public var fills = false
    /// Shown for selected lines and arrows; new ones take it from the tool (Line vs Arrow).
    public var arrow = true
    /// An arrowhead at the start as well as the end. Shown for the Arrow tool and for selected arrows.
    public var bothEnds = false
    /// Screenshots are usually 2× Retina, so 24 px reads as 12 pt: a normal label. Plain weight, like any text tool.
    public var fontSize: CGFloat = 24
    public var bold = false
    public var italic = false
    public var underline = false
    /// On by default: a solid box keeps text readable on any screenshot.
    public var boxed = true
    public var blurMode: BlurMode = .pixelate
    public var stepRadius: CGFloat = 20
    public var cornerRadius: CGFloat = 0

    public init() {}

    /// What the highlighter starts with: half see-through yellow, wide enough to cover a line of 2× text.
    public static let highlighter: StyleValues = {
        var values = StyleValues()
        values.color = .yellow
        values.opacity = 0.5
        values.width = 32
        return values
    }()

    public mutating func apply(_ change: StyleChange) {
        switch change {
        case .color(let value): color = value
        case .opacity(let value): opacity = value
        case .width(let value): width = value
        case .fill(let value): fills = value
        case .arrow(let value): arrow = value
        case .bothEnds(let value): bothEnds = value
        case .fontSize(let value): fontSize = value
        case .bold(let value): bold = value
        case .italic(let value): italic = value
        case .underline(let value): underline = value
        case .boxed(let value): boxed = value
        case .blurMode(let value): blurMode = value
        case .stepSize(let value): stepRadius = value
        case .cornerRadius(let value): cornerRadius = value
        }
    }

    /// The style a new annotation gets. Fill only for shapes that can be filled.
    public func style(canFill: Bool) -> Annotation.Style {
        let colour = color.withAlpha(opacity)
        return Annotation.Style(strokeColor: colour, strokeWidth: width, fillColor: canFill && fills ? colour : nil)
    }

    /// These values with the annotation's own values on top, for showing a selection.
    public func reading(_ annotation: Annotation) -> StyleValues {
        var values = self
        values.color = annotation.style.strokeColor.withAlpha(1)
        values.opacity = annotation.style.strokeColor.alpha
        values.width = annotation.style.strokeWidth
        values.fills = annotation.style.fillColor != nil
        annotation.kind.figure.read(into: &values)
        return values
    }
}
