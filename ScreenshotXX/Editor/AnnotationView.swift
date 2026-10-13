import ScreenshotXXCore
import SwiftUI

/// Draws one annotation at 1 pt = 1 image pixel. The one place that knows how each type looks.
struct AnnotationView: View {
    let annotation: Annotation
    let baseImage: CGImage

    var body: some View {
        let style = annotation.style
        let stroke = Color(style.strokeColor)
        let line = StrokeStyle(lineWidth: style.strokeWidth, lineCap: .round, lineJoin: .round)
        ZStack(alignment: .topLeading) {
            switch annotation.kind {
            case .line(let figure):
                Path { $0.move(to: figure.start); $0.addLine(to: figure.end) }.stroke(stroke, style: line)
                if figure.arrow { ArrowHead.path(from: figure.start, to: figure.end, strokeWidth: style.strokeWidth).fill(stroke) }
            case .curve(let figure):
                Path { $0.move(to: figure.start); $0.addQuadCurve(to: figure.end, control: figure.control) }.stroke(stroke, style: line)
                if figure.arrow { ArrowHead.path(from: figure.control, to: figure.end, strokeWidth: style.strokeWidth).fill(stroke) }
            case .freehand(let figure):
                Smoothing.path(through: figure.points).stroke(stroke, style: line)
            case .box(let figure):
                let rect = figure.rect.standardized
                let outline = figure.form == .ellipse
                    ? Path(ellipseIn: rect)
                    : Path(roundedRect: rect, cornerRadius: min(figure.cornerRadius, min(rect.width, rect.height) / 2))
                if let fill = style.fillColor { outline.fill(Color(fill)) }
                outline.stroke(stroke, style: line)
            case .text(let content):
                TextAnnotationView(content: content, color: style.strokeColor)
            case .bubble(let bubble):
                let shape = SpeechBubbleShape(box: bubble.rect.standardized, tail: bubble.tail)
                shape.fill(Color(style.fillColor ?? .white))
                shape.stroke(stroke, style: line)
                Text(bubble.text)
                    .font(.system(size: bubble.fontSize, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .multilineTextAlignment(.center)
                    .frame(width: bubble.textRect.width, height: bubble.textRect.height)
                    .offset(x: bubble.textRect.minX, y: bubble.textRect.minY)
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
                .foregroundStyle(content.boxed ? Color.white : Color(color))
                .fixedSize()
                .shadow(color: content.boxed ? .clear : .black.opacity(0.35), radius: content.fontSize * 0.06, y: 1)
                .offset(x: content.padding.width, y: content.padding.height)
        }
        .offset(x: content.origin.x, y: content.origin.y)
    }
}

enum ArrowHead {
    static func length(for strokeWidth: CGFloat) -> CGFloat { max(28, strokeWidth * 5) }

    /// A filled triangle with its tip at `to`, pointing away from `from`.
    static func path(from: CGPoint, to tip: CGPoint, strokeWidth: CGFloat) -> Path {
        let length = length(for: strokeWidth)
        let wings = ArrowGeometry.head(from: from, to: tip, length: length, width: length * 0.85)
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
