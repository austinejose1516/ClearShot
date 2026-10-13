import ScreenshotXXCore
import SwiftUI

/// Draws one annotation at 1 pt = 1 image pixel.
struct AnnotationView: View {
    let annotation: Annotation
    var baseImage: CGImage? = nil
    /// Called with the drawn size of a text box (not during export).
    var onTextMeasured: ((CGSize) -> Void)? = nil

    var body: some View {
        let style = annotation.style
        let stroke = StrokeStyle(lineWidth: style.strokeWidth, lineCap: .round, lineJoin: .round)
        ZStack(alignment: .topLeading) {
            switch annotation.kind {
            case .text(let content):
                TextAnnotationView(content: content, color: style.strokeColor, onMeasured: onTextMeasured)
            case .blur(let rect, let mode):
                if let baseImage { BlurRegionView(base: baseImage, rect: rect, mode: mode) }
            case .step(let number, _, let radius):
                let b = annotation.bounds
                Circle()
                    .fill(Color(style.strokeColor))
                    .overlay(Circle().stroke(.white, lineWidth: max(2, radius * 0.08)))
                    .overlay(Text("\(number)")
                        .font(.system(size: radius * 1.15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white))
                    .frame(width: b.width, height: b.height)
                    .offset(x: b.minX, y: b.minY)
            case .speechBubble(let rect, let tail, let text, let fontSize):
                let r = rect.standardized
                SpeechBubbleShape(box: r, tail: tail)
                    .fill(Color(style.fillColor ?? .white))
                SpeechBubbleShape(box: r, tail: tail)
                    .stroke(Color(style.strokeColor), style: stroke)
                Text(text)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .multilineTextAlignment(.center)
                    .frame(width: max(1, r.width - fontSize * 0.8), height: max(1, r.height - fontSize * 0.6))
                    .offset(x: r.minX + fontSize * 0.4, y: r.minY + fontSize * 0.3)
            default:
                if let fill = style.fillColor {
                    AnnotationShape(kind: annotation.kind).fill(Color(fill))
                }
                AnnotationShape(kind: annotation.kind).stroke(Color(style.strokeColor), style: stroke)
                ArrowHeadsShape(kind: annotation.kind, strokeWidth: style.strokeWidth).fill(Color(style.strokeColor))
            }
        }
    }
}

/// Text at its origin. Boxed = white text on a rounded box of the colour; plain = coloured text with a soft shadow.
struct TextAnnotationView: View {
    let content: TextContent
    let color: RGBAColor
    var onMeasured: ((CGSize) -> Void)? = nil

    var body: some View {
        Text(content.text)
            .font(.system(size: content.fontSize, weight: content.bold ? .bold : .medium))
            .foregroundStyle(content.boxed ? Color.white : Color(color))
            .padding(.horizontal, content.boxPadding)
            .padding(.vertical, content.boxPadding / 2)
            .background(content.boxed ? Color(color) : Color.clear,
                        in: RoundedRectangle(cornerRadius: content.fontSize * 0.25))
            .shadow(color: content.boxed ? .clear : .black.opacity(0.35), radius: content.fontSize * 0.06, y: 1)
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in onMeasured?(size) }
            .offset(x: content.origin.x, y: content.origin.y)
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
        case .curve(let start, let control, let end, _):
            path.move(to: start)
            path.addQuadCurve(to: end, control: control)
        case .text, .blur, .step, .speechBubble:
            break
        }
        return path
    }
}

/// Filled triangles at the ends of a line that asks for arrowheads.
struct ArrowHeadsShape: Shape {
    let kind: Annotation.Kind
    let strokeWidth: CGFloat

    nonisolated static func headLength(for strokeWidth: CGFloat) -> CGFloat { max(28, strokeWidth * 5) }

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        let length = Self.headLength(for: strokeWidth)
        let width = length * 0.85
        if case .curve(_, let control, let end, let arrowEnd) = kind, arrowEnd {
            let head = ArrowGeometry.head(from: control, to: end, length: length, width: width)
            path.move(to: end); path.addLine(to: head.left); path.addLine(to: head.right); path.closeSubpath()
            return path
        }
        guard case .line(let start, let end, let arrowStart, let arrowEnd) = kind else { return path }
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
