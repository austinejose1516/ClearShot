import CoreGraphics

public enum EditorTool: String, CaseIterable, Identifiable, Sendable {
    case select, line, arrow, curve, pen, highlight, rect, ellipse, text, bubble, step, blur, crop

    public var id: String { rawValue }

    /// How the toolbar groups the tools: Select · Draw · Shapes · Text · Fix.
    public static let groups: [[EditorTool]] = [
        [.select],
        [.line, .arrow, .curve, .pen, .highlight],
        [.rect, .ellipse],
        [.text, .bubble, .step],
        [.blur, .crop],
    ]

    public var title: String {
        switch self {
        case .select: "Select"
        case .line: "Line"
        case .arrow: "Arrow"
        case .curve: "Curved arrow"
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
        case .curve: "point.topleft.down.to.point.bottomright.curvepath"
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
        case .select: "Click to select · drag to move · drag a dot to resize · Delete removes"
        case .line, .arrow: "Drag to draw"
        case .curve: "Drag to draw a straight arrow, then drag the middle dot to bend it to either side"
        case .pen: "Drag to draw freehand"
        case .highlight: "Drag over the text to mark it"
        case .rect: "Drag to draw · Fill makes it solid · Corners rounds it"
        case .ellipse: "Drag to draw · Fill makes it solid"
        case .text: "Drag a box (sets the size) or click, then type · Enter finishes · ⌘Enter adds a line"
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
        case .line, .arrow, .curve, .pen, .highlight: [.color, .width]
        case .rect: [.color, .width, .fill, .corners]
        case .ellipse: [.color, .width, .fill]
        case .text: [.color, .fontSize, .textStyle]
        case .bubble: [.color, .width, .fontSize]
        case .step: [.color, .stepSize]
        case .blur: [.blurMode]
        }
    }

    /// Pen, Highlighter, Step and Blur are used several times in a row; the other drawing tools hand back to
    /// Select after one annotation, so it can be adjusted straight away.
    public var staysActive: Bool {
        switch self {
        case .select, .pen, .highlight, .step, .blur, .crop: true
        case .line, .arrow, .curve, .rect, .ellipse, .text, .bubble: false
        }
    }

    /// Pressing on an existing annotation selects it instead of starting a new one. The strokes and the crop
    /// start anywhere, even over an annotation.
    public var grabsExisting: Bool { ![.pen, .highlight, .crop].contains(self) }

    /// What a drag from `start` to `end` draws with this tool; nil for tools that do not draw by dragging.
    public func figure(from start: CGPoint, to end: CGPoint, values: StyleValues) -> (any Figure)? {
        let area = SelectionGeometry.normalizedRect(from: start, to: end)
        return switch self {
        case .line: Line(start: start, end: end)
        case .arrow: Line(start: start, end: end, arrow: true)
        case .curve: Curve(start: start, end: end, arrow: true)
        case .rect: Box(rect: area, form: .rectangle, cornerRadius: values.cornerRadius)
        case .ellipse: Box(rect: area, form: .ellipse)
        case .bubble: Bubble.drawn(from: start, to: end)
        case .blur: Blur(rect: area, mode: values.blurMode)
        case .select, .pen, .highlight, .text, .step, .crop: nil
        }
    }
}
