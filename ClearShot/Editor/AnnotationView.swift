import ClearShotCore
import SwiftUI

/// Draws one annotation at 1 pt = 1 image pixel. The one place that knows how each type looks.
struct AnnotationView: View {
    let annotation: Annotation
    let baseImage: CGImage
    /// While its text is being edited: the inline editor draws the text (and a text annotation's box),
    /// but a bubble still draws its shape, so typing happens on the real bubble.
    var hidesText = false

    var body: some View {
        let style = annotation.style
        let stroke = Color(style.strokeColor)
        let line = StrokeStyle(lineWidth: style.strokeWidth, lineCap: .round, lineJoin: .round)
        ZStack(alignment: .topLeading) {
            switch annotation.kind {
            case .line(let figure):
                // With an arrow, the line stops where the head starts, and the head points along the line.
                let headLength = ArrowGeometry.headLength(strokeWidth: style.strokeWidth)
                let lineEnd = figure.arrow ? figure.pointBefore(end: headLength) : figure.end
                Path { $0.move(to: figure.start); $0.addLine(to: lineEnd) }.stroke(stroke, style: line)
                if figure.arrow { ArrowHead.path(base: lineEnd, tip: figure.end, strokeWidth: style.strokeWidth).fill(stroke) }
            case .curve(let figure):
                // Each head's base sits on the curve, so the curve flows into the middle of the head.
                let headLength = ArrowGeometry.headLength(strokeWidth: style.strokeWidth)
                let last = figure.arrow ? figure.pointBefore(end: headLength) : (point: figure.end, t: 1)
                let first = figure.arrow && figure.bothEnds ? figure.pointAfter(start: headLength) : (point: figure.start, t: 0)
                let shown = figure.segment(from: first.t, to: last.t)
                Path { $0.move(to: shown.start); $0.addQuadCurve(to: shown.end, control: shown.control) }.stroke(stroke, style: line)
                if figure.arrow {
                    ArrowHead.path(base: last.point, tip: figure.end, strokeWidth: style.strokeWidth).fill(stroke)
                    if figure.bothEnds {
                        ArrowHead.path(base: first.point, tip: figure.start, strokeWidth: style.strokeWidth).fill(stroke)
                    }
                }
            case .freehand(let figure):
                // A highlighter multiplies onto the image, like ink on paper: text under it stays crisp and dark.
                Smoothing.path(through: figure.points)
                    .stroke(stroke, style: line)
                    .blendMode(figure.form == .highlighter ? .multiply : .normal)
            case .box(let figure):
                let rect = figure.rect.standardized
                let outline = figure.form == .ellipse
                    ? Path(ellipseIn: rect)
                    : Path(roundedRect: rect, cornerRadius: min(figure.cornerRadius, min(rect.width, rect.height) / 2))
                if let fill = style.fillColor { outline.fill(Color(fill)) }
                outline.stroke(stroke, style: line)
            case .text(let content):
                if !hidesText { TextAnnotationView(content: content, color: style.strokeColor) }
            case .bubble(let bubble):
                let shape = SpeechBubbleShape(box: bubble.rect.standardized, tail: bubble.tail)
                shape.fill(Color(style.fillColor ?? .white))
                shape.stroke(stroke, style: line)
                if !hidesText {
                    Text(bubble.text)
                        .font(Font(bubble.font))
                        .foregroundStyle(Color.black)
                        .multilineTextAlignment(.center)
                        .frame(width: bubble.textRect.width, height: bubble.textRect.height)
                        .offset(x: bubble.textRect.minX, y: bubble.textRect.minY)
                }
            case .step(let step):
                let bounds = step.bounds
                Circle()
                    .fill(stroke)
                    .overlay(Circle().stroke(.white, lineWidth: max(2, step.radius * 0.08)))
                    .overlay(Text("\(step.number)")
                        .font(.system(size: step.radius * 1.15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white))
                    .frame(width: bounds.width, height: bounds.height)
                    .offset(x: bounds.minX, y: bounds.minY)
            case .blur(let blur):
                BlurRegionView(base: baseImage, rect: blur.rect, mode: blur.mode)
            }
        }
    }
}

/// Text drawn with the exact font Core measured it with, inside the box Core computed.
struct TextAnnotationView: View {
    let content: TextContent
    let color: RGBAColor

    var body: some View {
        let size = content.size
        ZStack(alignment: .topLeading) {
            if content.boxed {
                RoundedRectangle(cornerRadius: content.cornerRadius)
                    .fill(Color(color))
                    .frame(width: size.width, height: size.height)
            }
            Text(content.text)
                .font(Font(content.font))
                .underline(content.underline)
                .foregroundStyle(content.boxed ? Color.white : Color(color))
                .fixedSize()
                .shadow(color: content.boxed ? .clear : .black.opacity(0.35), radius: content.fontSize * 0.06, y: 1)
                .offset(x: content.padding.width, y: content.padding.height)
        }
        .offset(x: content.origin.x, y: content.origin.y)
    }
}

enum ArrowHead {
    /// A filled triangle from `base` (the middle of its back edge) to `tip`.
    static func path(base: CGPoint, tip: CGPoint, strokeWidth: CGFloat) -> Path {
        let length = hypot(tip.x - base.x, tip.y - base.y)
        let width = ArrowGeometry.headLength(strokeWidth: strokeWidth) * 0.9
        let wings = ArrowGeometry.head(from: base, to: tip, length: length, width: width)
        return Path { path in
            path.move(to: tip)
            path.addLine(to: wings.left)
            path.addLine(to: wings.right)
            path.closeSubpath()
        }
    }
}

enum Smoothing {
    /// A smooth curve through pen points.
    static func path(through points: [CGPoint]) -> Path {
        Path { path in
            if let smooth = PathSmoother.segments(through: points) {
                path.move(to: smooth.start)
                for segment in smooth.segments {
                    path.addCurve(to: segment.end, control1: segment.control1, control2: segment.control2)
                }
            } else if let only = points.first {
                path.addEllipse(in: CGRect(x: only.x - 0.5, y: only.y - 0.5, width: 1, height: 1))
            }
        }
    }
}
