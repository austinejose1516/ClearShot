enum EditorTool: String, CaseIterable, Identifiable {
    case select, line, arrow, curve, pen, rect, ellipse, text

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
        }
    }

    var symbol: String {
        switch self {
        case .select: "cursorarrow"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .curve: "arrow.turn.up.right"
        case .pen: "scribble"
        case .rect: "rectangle"
        case .ellipse: "circle"
        case .text: "textformat"
        }
    }

    var usesFill: Bool { self == .rect || self == .ellipse }
}
