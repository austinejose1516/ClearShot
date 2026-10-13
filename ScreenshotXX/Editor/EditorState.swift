import Observation
import ScreenshotXXCore
import SwiftUI

/// UI state of one editor window: active tool, current style, zoom.
@Observable
final class EditorState {
    var tool: EditorTool = .select
    var strokeColor: RGBAColor = .red
    var strokeWidth: CGFloat = 6
    var fills = false
    var zoom: CGFloat = 1
    var zoomIsFit = true

    var style: Annotation.Style {
        Annotation.Style(strokeColor: strokeColor, strokeWidth: strokeWidth, fillColor: fills ? strokeColor : nil)
    }

    static let widths: [CGFloat] = [2, 4, 6, 8, 12, 16, 24]

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
            annotation.style.strokeColor = strokeColor
            annotation.style.strokeWidth = strokeWidth
            switch annotation.kind {
            case .rect, .ellipse: annotation.style.fillColor = fills ? strokeColor : nil
            default: break
            }
            document.update(annotation)
        }
        document.commit()
    }
}
