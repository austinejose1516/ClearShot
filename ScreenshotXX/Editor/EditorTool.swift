enum EditorTool: String, CaseIterable, Identifiable {
    case select, line, arrow, curve, pen, rect, ellipse, text, bubble, step, blur, crop

    var id: String { rawValue }

    var title: String {
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

    var symbol: String {
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

    var usesFill: Bool { self == .rect || self == .ellipse }
}
