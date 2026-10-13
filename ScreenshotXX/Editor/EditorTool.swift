enum EditorTool: String, CaseIterable, Identifiable {
    case select, line, arrow, pen, rect, ellipse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: "Select"
        case .line: "Line"
        case .arrow: "Arrow"
        case .pen: "Pen"
        case .rect: "Rectangle"
        case .ellipse: "Ellipse"
        }
    }

    var symbol: String {
        switch self {
        case .select: "cursorarrow"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .pen: "scribble"
        case .rect: "rectangle"
        case .ellipse: "circle"
        }
    }

    var usesFill: Bool { self == .rect || self == .ellipse }
}
