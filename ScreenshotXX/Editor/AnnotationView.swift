import ScreenshotXXCore
import SwiftUI

/// Draws one annotation at 1 pt = 1 image pixel.
struct AnnotationView: View {
    let annotation: Annotation

    var body: some View {
        let style = annotation.style
        let stroke = StrokeStyle(lineWidth: style.strokeWidth, lineCap: .round, lineJoin: .round)
        ZStack(alignment: .topLeading) {
            if let fill = style.fillColor {
                AnnotationShape(kind: annotation.kind).fill(Color(fill))
            }
            AnnotationShape(kind: annotation.kind).stroke(Color(style.strokeColor), style: stroke)
            ArrowHeadsShape(kind: annotation.kind, strokeWidth: style.strokeWidth).fill(Color(style.strokeColor))
        }
    }
}

/// The outline of an annotation as a SwiftUI Shape (ignores its frame; coordinates are absolute).
struct AnnotationShape: Shape {
    let kind: Annotation.Kind

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        switch kind {
        case .line(let start, let end, _, _):
            path.move(to: start)
            path.addLine(to: end)
        case .freehand(let points):
            if let smooth = PathSmoother.segments(through: points) {
                path.move(to: smooth.start)
                for segment in smooth.segments {
                    path.addCurve(to: segment.end, control1: segment.control1, control2: segment.control2)
                }
            } else if let only = points.first {
                path.addEllipse(in: CGRect(x: only.x - 0.5, y: only.y - 0.5, width: 1, height: 1))
            }
        case .rect(let r):
            path.addRect(r.standardized)
        case .ellipse(let r):
            path.addEllipse(in: r.standardized)
        }
        return path
    }
}

/// Filled triangles at the ends of a line that asks for arrowheads.
struct ArrowHeadsShape: Shape {
    let kind: Annotation.Kind
    let strokeWidth: CGFloat

    nonisolated static func headLength(for strokeWidth: CGFloat) -> CGFloat { max(14, strokeWidth * 3) }

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        guard case .line(let start, let end, let arrowStart, let arrowEnd) = kind else { return path }
        let length = Self.headLength(for: strokeWidth)
        let width = length * 0.9
        if arrowEnd {
            let head = ArrowGeometry.head(from: start, to: end, length: length, width: width)
            path.move(to: end); path.addLine(to: head.left); path.addLine(to: head.right); path.closeSubpath()
        }
        if arrowStart {
            let head = ArrowGeometry.head(from: end, to: start, length: length, width: width)
            path.move(to: start); path.addLine(to: head.left); path.addLine(to: head.right); path.closeSubpath()
        }
        return path
    }
}
