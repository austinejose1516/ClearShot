import CoreGraphics
import Foundation

/// A text annotation. `measuredSize` is the drawn box (text plus padding) reported by the view;
/// until then `estimatedSize` keeps hit testing and handles roughly right.
public struct TextContent: Equatable, Sendable, Codable {
    public static let minimumFontSize: CGFloat = 8

    public var text: String
    public var origin: CGPoint
    public var fontSize: CGFloat
    public var bold: Bool
    public var boxed: Bool
    public var measuredSize: CGSize

    public init(text: String, origin: CGPoint, fontSize: CGFloat = 48, bold: Bool = true,
                boxed: Bool = false, measuredSize: CGSize = .zero) {
        self.text = text
        self.origin = origin
        self.fontSize = fontSize
        self.bold = bold
        self.boxed = boxed
        self.measuredSize = measuredSize
    }

    /// The font size whose one-line box is `height` tall (line height 1.2× plus the box padding when boxed).
    public static func fontSize(forBoxHeight height: CGFloat, boxed: Bool) -> CGFloat {
        max(minimumFontSize, (height / (boxed ? 1.5 : 1.2)).rounded())
    }

    /// Horizontal padding inside a box, relative to the font size.
    public var boxPadding: CGFloat { boxed ? fontSize * 0.3 : 0 }

    public var estimatedSize: CGSize {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let longest = lines.map(\.count).max() ?? 0
        return CGSize(width: (CGFloat(max(longest, 1)) * fontSize * 0.55 + boxPadding * 2).rounded(),
                      height: (CGFloat(max(lines.count, 1)) * fontSize * 1.2 + boxPadding).rounded())
    }

    public var frame: CGRect {
        CGRect(origin: origin, size: measuredSize == .zero ? estimatedSize : measuredSize)
    }

    /// Same text, scaled so its box becomes `newWidth` wide (corner-handle resize).
    public func scaled(toWidth newWidth: CGFloat) -> TextContent {
        let currentWidth = frame.width
        guard currentWidth > 0 else { return self }
        let factor = max(newWidth, 1) / currentWidth
        var result = self
        result.fontSize = max(Self.minimumFontSize, fontSize * factor)
        let applied = result.fontSize / fontSize
        if measuredSize != .zero {
            result.measuredSize = CGSize(width: measuredSize.width * applied, height: measuredSize.height * applied)
        }
        return result
    }
}
