import Observation
import ScreenshotXXCore
import SwiftUI

/// UI state of one editor window: active tool, current style, zoom.
@Observable
final class EditorState {
    var tool: EditorTool = .select
    var strokeColor: RGBAColor = .red
    var strokeWidth: CGFloat = 8
    var fills = false
    var opacity: Double = 1
    var zoom: CGFloat = 1
    var zoomIsFit = true
    var fontSize: CGFloat = 48
    var bold = true
    var boxed = false
    var editingTextID: Annotation.ID?
    var showsFramePanel = false
    var blurMode: BlurMode = .pixelate
    var cropDraft: CGRect?
    var stepRadius: CGFloat = 36
    var editingTextIsNew = false

    static let fontSizes: [CGFloat] = [16, 24, 32, 48, 64, 96, 128]

    var style: Annotation.Style {
        let color = strokeColor.withAlpha(opacity)
        return Annotation.Style(strokeColor: color, strokeWidth: strokeWidth, fillColor: fills ? color : nil)
    }

    static let widths: [CGFloat] = [2, 4, 6, 8, 12, 16, 24, 32]
    static let opacities: [Double] = [1, 0.75, 0.5, 0.25]

    func fitZoom(imageSize: CGSize, viewport: CGSize) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 1 }
        let padding: CGFloat = 48
        let fit = min((viewport.width - padding) / imageSize.width, (viewport.height - padding) / imageSize.height)
        return max(0.05, min(1, fit))
    }

    /// Push the current colour / width / fill onto the selected annotations.
    func applyStyle(to document: EditorDocument) {
        guard !document.selection.isEmpty else { return }
        for id in document.selection {
            guard var annotation = document.annotation(id: id) else { continue }
            let color = strokeColor.withAlpha(opacity)
            annotation.style.strokeColor = color
            annotation.style.strokeWidth = strokeWidth
            switch annotation.kind {
            case .rect, .ellipse:
                annotation.style.fillColor = fills ? color : nil
            case .text(var content):
                content.fontSize = fontSize
                content.bold = bold
                content.boxed = boxed
                annotation.kind = .text(content)
            case .speechBubble(let rect, let tail, let text, _):
                annotation.kind = .speechBubble(rect: rect, tail: tail, text: text, fontSize: fontSize)
            case .blur(let rect, _):
                annotation.kind = .blur(rect: rect, mode: blurMode)
            default:
                break
            }
            document.update(annotation)
        }
        document.commit()
    }

    /// Turn the arrowhead on or off for selected lines and curves.
    func applyArrowhead(_ on: Bool, to document: EditorDocument) {
        for id in document.selection {
            guard var annotation = document.annotation(id: id) else { continue }
            switch annotation.kind {
            case .line(let s, let e, let a, _): annotation.kind = .line(start: s, end: e, arrowStart: a, arrowEnd: on)
            case .curve(let s, let c, let e, _): annotation.kind = .curve(start: s, control: c, end: e, arrowEnd: on)
            default: continue
            }
            document.update(annotation)
        }
        document.commit()
    }

    /// Load the style of one annotation into the toolbar (when it gets selected).
    func adopt(_ annotation: Annotation) {
        strokeColor = annotation.style.strokeColor.withAlpha(1)
        opacity = annotation.style.strokeColor.alpha
        strokeWidth = annotation.style.strokeWidth
        fills = annotation.style.fillColor != nil
        switch annotation.kind {
        case .text(let content):
            fontSize = content.fontSize
            bold = content.bold
            boxed = content.boxed
        case .speechBubble(_, _, _, let size):
            fontSize = size
        case .blur(_, let mode):
            blurMode = mode
        default:
            break
        }
    }
}
