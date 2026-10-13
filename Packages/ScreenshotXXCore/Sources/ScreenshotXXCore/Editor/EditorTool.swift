import CoreGraphics

public enum EditorTool: String, CaseIterable, Identifiable, Sendable {
    case select, line, arrow, curve, pen, rect, ellipse, text, bubble, step, blur, crop

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .select: "Select"
        case .line: "Line"
        case .arrow: "Arrow"
        case .curve: "Curved arrow"
        case .pen: "Pen"
        case .rect: "Rectangle"
        case .ellipse: "Ellipse"
        case .text: "Text"
        case .bubble: "Speech bubble"
        case .step: "Step number"
        case .blur: "Blur / pixelate"
        case .crop: "Crop"
        }
    }

    /// SF Symbol name.
    public var symbol: String {
        switch self {
        case .select: "cursorarrow"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .curve: "point.topleft.down.to.point.bottomright.curvepath"
        case .pen: "scribble"
        case .rect: "rectangle"
        case .ellipse: "circle"
        case .text: "textformat"
        case .bubble: "bubble.left"
        case .step: "1.circle"
        case .blur: "eye.slash"
        case .crop: "crop"
        }
    }

    /// One line of help, shown when the tool is picked.
    public var hint: String {
        switch self {
        case .select: "Click to select · drag to move · drag a dot to resize · Delete removes"
        case .line, .arrow: "Drag to draw"
        case .curve: "Drag to draw, then drag the middle dot to bend"
        case .pen: "Drag to draw freehand"
        case .rect, .ellipse: "Drag to draw · Fill makes it solid"
        case .text: "Drag a box (sets the size) or click, then type · Enter finishes"
        case .bubble: "Drag to draw the bubble, type, then drag its tail"
        case .step: "Click to place the next number · drag a corner dot to resize"
        case .blur: "Drag over the part to hide"
        case .crop: "Drag the part to keep, then press Crop or Enter"
        }
    }

    /// Toolbar controls that matter for what this tool makes.
    public var capabilities: StyleCapabilities {
        switch self {
        case .select, .crop: []
        case .line, .arrow, .curve, .pen: [.color, .width]
        case .rect, .ellipse: [.color, .width, .fill]
        case .text: [.color, .fontSize, .textStyle]
        case .bubble: [.color, .width, .fontSize]
        case .step: [.color, .stepSize]
        case .blur: [.blurMode]
        }
    }

    /// Pressing on an existing annotation selects it instead of starting a new one.
    public var grabsExisting: Bool { self != .pen && self != .crop }

    /// What a drag from `start` to `end` draws with this tool; nil for tools that do not draw by dragging.
    public func figure(from start: CGPoint, to end: CGPoint, values: StyleValues) -> (any Figure)? {
        let area = SelectionGeometry.normalizedRect(from: start, to: end)
        return switch self {
        case .line: Line(start: start, end: end)
        case .arrow: Line(start: start, end: end, arrow: true)
        case .curve: Curve.bent(from: start, to: end, arrow: true)
        case .rect: Box(rect: area, form: .rectangle)
        case .ellipse: Box(rect: area, form: .ellipse)
        case .bubble: Bubble.drawn(from: start, to: end)
        case .blur: Blur(rect: area, mode: values.blurMode)
        case .select, .pen, .text, .step, .crop: nil
        }
    }
}
