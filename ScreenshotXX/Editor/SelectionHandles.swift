import ScreenshotXXCore
import SwiftUI

enum HandleKind: Equatable {
    case lineStart, lineEnd, curveControl
    case topLeft, topRight, bottomLeft, bottomRight
}

enum Handles {
    /// Handle positions in image coordinates.
    static func positions(for annotation: Annotation) -> [(kind: HandleKind, point: CGPoint)] {
        switch annotation.kind {
        case .line(let start, let end, _, _):
            return [(.lineStart, start), (.lineEnd, end)]
        case .rect(let r), .ellipse(let r):
            let b = r.standardized
            return [(.topLeft, CGPoint(x: b.minX, y: b.minY)), (.topRight, CGPoint(x: b.maxX, y: b.minY)),
                    (.bottomLeft, CGPoint(x: b.minX, y: b.maxY)), (.bottomRight, CGPoint(x: b.maxX, y: b.maxY))]
        case .curve(let start, let control, let end, _):
            return [(.lineStart, start), (.curveControl, control), (.lineEnd, end)]
        case .text(let content):
            let b = content.frame
            return [(.topLeft, CGPoint(x: b.minX, y: b.minY)), (.topRight, CGPoint(x: b.maxX, y: b.minY)),
                    (.bottomLeft, CGPoint(x: b.minX, y: b.maxY)), (.bottomRight, CGPoint(x: b.maxX, y: b.maxY))]
        case .freehand:
            return []
        }
    }

    /// The annotation after dragging `handle` to `point`.
    static func apply(_ handle: HandleKind, to annotation: Annotation, point: CGPoint) -> Annotation {
        var result = annotation
        switch (annotation.kind, handle) {
        case (.line(_, let end, let a, let b), .lineStart):
            result.kind = .line(start: point, end: end, arrowStart: a, arrowEnd: b)
        case (.line(let start, _, let a, let b), .lineEnd):
            result.kind = .line(start: start, end: point, arrowStart: a, arrowEnd: b)
        case (.rect(let r), _):
            result.kind = .rect(resized(r, handle, point))
        case (.ellipse(let r), _):
            result.kind = .ellipse(resized(r, handle, point))
        case (.curve(_, let c, let e, let a), .lineStart):
            result.kind = .curve(start: point, control: c, end: e, arrowEnd: a)
        case (.curve(let s, _, let e, let a), .curveControl):
            result.kind = .curve(start: s, control: point, end: e, arrowEnd: a)
        case (.curve(let s, let c, _, let a), .lineEnd):
            result.kind = .curve(start: s, control: c, end: point, arrowEnd: a)
        case (.text(let content), _):
            result.kind = .text(scaledText(content, handle, point))
        default:
            break
        }
        return result
    }

    /// Corner drag scales the font; the opposite corner stays where it is.
    private static func scaledText(_ content: TextContent, _ handle: HandleKind, _ point: CGPoint) -> TextContent {
        let b = content.frame
        let anchor: CGPoint
        switch handle {
        case .topLeft: anchor = CGPoint(x: b.maxX, y: b.maxY)
        case .topRight: anchor = CGPoint(x: b.minX, y: b.maxY)
        case .bottomLeft: anchor = CGPoint(x: b.maxX, y: b.minY)
        case .bottomRight: anchor = CGPoint(x: b.minX, y: b.minY)
        default: return content
        }
        var scaled = content.scaled(toWidth: abs(point.x - anchor.x))
        let size = scaled.frame.size
        scaled.origin = CGPoint(x: handle == .topRight || handle == .bottomRight ? anchor.x : anchor.x - size.width,
                                y: handle == .bottomLeft || handle == .bottomRight ? anchor.y : anchor.y - size.height)
        return scaled
    }

    private static func resized(_ rect: CGRect, _ handle: HandleKind, _ point: CGPoint) -> CGRect {
        let b = rect.standardized
        let anchor: CGPoint
        switch handle {
        case .topLeft: anchor = CGPoint(x: b.maxX, y: b.maxY)
        case .topRight: anchor = CGPoint(x: b.minX, y: b.maxY)
        case .bottomLeft: anchor = CGPoint(x: b.maxX, y: b.minY)
        case .bottomRight: anchor = CGPoint(x: b.minX, y: b.minY)
        default: return b
        }
        return SelectionGeometry.normalizedRect(from: anchor, to: point)
    }
}

/// Dashed bounds and handles for the selected annotations, drawn in zoomed space so they keep a constant size.
struct SelectionOverlay: View {
    let document: EditorDocument
    let zoom: CGFloat
    var hiddenID: Annotation.ID? = nil

    var body: some View {
        ForEach(document.annotations.filter { document.selection.contains($0.id) && $0.id != hiddenID }) { annotation in
            let b = annotation.bounds
            Rectangle()
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: max(1, b.width * zoom), height: max(1, b.height * zoom))
                .offset(x: b.minX * zoom, y: b.minY * zoom)
            ForEach(Array(Handles.positions(for: annotation).enumerated()), id: \.offset) { _, handle in
                Circle()
                    .fill(.white)
                    .stroke(Color.accentColor, lineWidth: 1.5)
                    .frame(width: 10, height: 10)
                    .offset(x: handle.point.x * zoom - 5, y: handle.point.y * zoom - 5)
            }
        }
        .allowsHitTesting(false)
    }
}
