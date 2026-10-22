import CoreGraphics

public enum EditorTool: String, CaseIterable, Identifiable, Sendable {
    case select, line, arrow, pen, highlight, rect, ellipse, text, bubble, step, blur, crop

    public var id: String { rawValue }

    /// How the toolbar groups the tools: Select · Draw · Shapes · Text · Fix.
    public static let groups: [[EditorTool]] = [
        [.select],
        [.line, .arrow, .pen, .highlight],
        [.rect, .ellipse],
        [.text, .bubble, .step],
        [.blur, .crop],
    ]

    public var title: String {
        switch self {
        case .select: "Select"
        case .line: "Line"
        case .arrow: "Arrow"
        case .pen: "Pen"
        case .highlight: "Highlighter"
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
        case .pen: "scribble"
        case .highlight: "highlighter"
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
        case .select: "Click to select · drag to move · drag a dot to resize (⇧ keeps the shape) · Delete removes"
        case .line: "Drag to draw · ⇧ snaps to 45°"
        case .arrow: "Drag to draw · drag the middle dot to bend it, double-click it to straighten · ⇧ snaps to 45° · Both ends adds a head"
        case .pen: "Drag to draw freehand"
        case .highlight: "Drag over the text to mark it"
        case .rect: "Drag to draw · ⇧ for a square · Fill makes it solid · Corners rounds it"
        case .ellipse: "Drag to draw · ⇧ for a circle · Fill makes it solid"
        case .text: "Click and type · Enter finishes · ⌘Enter adds a line · Box turns the background on or off"
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
        case .line, .pen, .highlight: [.color, .width]
        case .arrow: [.color, .width, .bothEnds]
        case .rect: [.color, .width, .fill, .corners]
        case .ellipse: [.color, .width, .fill]
        case .text: [.color, .fontSize, .textStyle]
        case .bubble: [.color, .width, .fontSize]
        case .step: [.color, .stepSize]
        case .blur: [.blurMode]
        }
    }

    /// Pressing on an existing annotation selects it instead of starting a new one, so every tool stays on
    /// (until Esc or Select) and shapes can still be moved and resized while it is. The strokes and the crop
    /// start anywhere, even over an annotation.
    public var grabsExisting: Bool { ![.pen, .highlight, .crop].contains(self) }

    /// What a drag from `start` to `end` draws with this tool; nil for tools that do not draw by dragging.
    /// `constrained` (⇧ held): a square or a circle, and a line at the nearest 45°.
    public func figure(from start: CGPoint, to end: CGPoint, values: StyleValues, constrained: Bool = false) -> (any Figure)? {
        let squareEnd = constrained ? ConstrainedGeometry.squareEnd(from: start, to: end) : end
        let snappedEnd = constrained ? ConstrainedGeometry.snappedEnd(from: start, to: end) : end
        let area = SelectionGeometry.normalizedRect(from: start, to: squareEnd)
        return switch self {
        case .line: Line(start: start, end: snappedEnd)
        case .arrow: Curve(start: start, end: snappedEnd, arrow: true, bothEnds: values.bothEnds)
        case .rect: Box(rect: area, form: .rectangle, cornerRadius: values.cornerRadius)
        case .ellipse: Box(rect: area, form: .ellipse)
        case .bubble: Bubble.drawn(from: start, to: end, fontSize: values.fontSize)
        case .blur: Blur(rect: area, mode: values.blurMode)
        case .select, .pen, .highlight, .text, .step, .crop: nil
        }
    }
}
