import CoreGraphics

/// The editor's zoom. "Fit" follows the window; a fixed scale stays until the user changes it.
public struct CanvasZoom: Equatable, Sendable {
    public enum Mode: Hashable, Sendable {
        case fit
        case scale(CGFloat)
    }

    public static let range: ClosedRange<CGFloat> = 0.05...8
    /// One ⌘+ or ⌘− step.
    public static let step: CGFloat = 1.25
    /// Space left around a fitted canvas, in view points.
    public static let fitMargin: CGFloat = 48

    public var mode: Mode = .fit
    public var canvasSize: CGSize = .zero
    public var viewportSize: CGSize = .zero

    public init() {}

    /// The scale that shows the whole canvas; never past 100 %.
    public var fitScale: CGFloat {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return 1 }
        let fit = min((viewportSize.width - Self.fitMargin) / canvasSize.width,
                      (viewportSize.height - Self.fitMargin) / canvasSize.height)
        return min(1, max(Self.range.lowerBound, fit))
    }

    public var scale: CGFloat {
        switch mode {
        case .fit: fitScale
        case .scale(let scale): scale
        }
    }

    public var isFit: Bool { mode == .fit }

    /// "50 %"
    public var label: String { "\(Int((scale * 100).rounded())) %" }

    public mutating func set(scale: CGFloat) {
        mode = .scale(min(Self.range.upperBound, max(Self.range.lowerBound, scale)))
    }

    public mutating func zoom(by factor: CGFloat) {
        set(scale: scale * factor)
    }
}
