import CoreGraphics
import CoreText
import Foundation

/// A text annotation. Its size is measured here with CoreText, so the box, the handles and hit testing are
/// exact from the start, and the editor draws the text with the same font (`font`).
public struct TextContent: Figure {
    public static let minimumFontSize: CGFloat = 8

    public var text: String
    public var origin: CGPoint
    public var fontSize: CGFloat
    public var bold: Bool
    public var boxed: Bool

    public init(text: String, origin: CGPoint, fontSize: CGFloat = 48, bold: Bool = true, boxed: Bool = false) {
        self.text = text
        self.origin = origin
        self.fontSize = fontSize
        self.bold = bold
        self.boxed = boxed
    }

    /// The font size whose one-line box is `height` tall (line height 1.2×, plus padding when boxed).
    public static func fontSize(forBoxHeight height: CGFloat, boxed: Bool) -> CGFloat {
        max(minimumFontSize, (height / (boxed ? 1.5 : 1.2)).rounded())
    }

    /// The system font at this size, bold or medium.
    public var font: CTFont { TextMetrics.font(size: fontSize, bold: bold) }
    /// Space between the text and the edge of its box; zero when not boxed.
    public var padding: CGSize { boxed ? CGSize(width: fontSize * 0.3, height: fontSize * 0.15) : .zero }
    public var cornerRadius: CGFloat { fontSize * 0.25 }
    /// The text alone. Empty text still has one line of height.
    public var textSize: CGSize { TextMetrics.size(of: text.isEmpty ? " " : text, font: font) }
    /// The whole box: text plus padding.
    public var size: CGSize {
        CGSize(width: textSize.width + 2 * padding.width, height: textSize.height + 2 * padding.height)
    }
    public var frame: CGRect { CGRect(origin: origin, size: size) }

    public var bounds: CGRect { frame }
    public var handles: [Handle] { frame.cornerHandles }
    public var capabilities: StyleCapabilities { [.color, .fontSize, .textStyle] }
    public var editableText: String? { text }
    public var asKind: Annotation.Kind { .text(self) }

    public func hitTest(_ point: CGPoint, tolerance: CGFloat, style: Annotation.Style) -> Bool {
        frame.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
    }

    public mutating func move(by delta: CGVector) {
        origin = origin.offset(delta)
    }

    /// A corner drag scales the font; the opposite corner stays where it is.
    public mutating func drag(_ handle: HandleKind, to point: CGPoint) {
        let current = frame
        guard let anchor = current.anchor(opposite: handle), current.width > 0 else { return }
        fontSize = max(Self.minimumFontSize, fontSize * max(1, abs(point.x - anchor.x)) / current.width)
        let newSize = size
        let growsRight = handle == .topRight || handle == .bottomRight
        let growsDown = handle == .bottomLeft || handle == .bottomRight
        origin = CGPoint(x: growsRight ? anchor.x : anchor.x - newSize.width,
                         y: growsDown ? anchor.y : anchor.y - newSize.height)
    }

    public mutating func apply(_ change: StyleChange) {
        switch change {
        case .fontSize(let size): fontSize = size
        case .bold(let on): bold = on
        case .boxed(let on): boxed = on
        default: break
        }
    }

    public func read(into values: inout StyleValues) {
        values.fontSize = fontSize
        values.bold = bold
        values.boxed = boxed
    }

    public mutating func setEditableText(_ text: String) { self.text = text }
}

enum TextMetrics {
    static func font(size: CGFloat, bold: Bool) -> CTFont {
        guard let system = CTFontCreateUIFontForLanguage(.system, size, nil) else {
            return CTFontCreateWithName("Helvetica" as CFString, size, nil)
        }
        // Weight values match NSFont.Weight.bold (0.4) and .medium (0.23).
        let traits = [kCTFontWeightTrait as String: bold ? 0.4 : 0.23] as CFDictionary
        let attributes = [kCTFontTraitsAttribute as String: traits] as CFDictionary
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(CTFontCopyFontDescriptor(system), attributes)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    static func size(of text: String, font: CTFont) -> CGSize {
        let attributes = [kCTFontAttributeName as String: font] as CFDictionary
        guard let attributed = CFAttributedStringCreate(nil, text as CFString, attributes) else { return .zero }
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let fitted = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRange(location: 0, length: 0), nil,
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), nil)
        return CGSize(width: ceil(fitted.width), height: ceil(fitted.height))
    }
}
