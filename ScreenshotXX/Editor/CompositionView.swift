import ScreenshotXXCore
import SwiftUI

/// The export canvas: background, then the image with its annotations.
/// 1 pt = 1 canvas pixel. Used on screen (scaled by the canvas) and for export (scale 1), so both match.
struct CompositionView: View {
    let document: EditorDocument
    /// The text being edited inline is drawn by the editing field instead.
    var hiddenAnnotationID: Annotation.ID? = nil
    var isExport = false

    var body: some View {
        let layout = document.layout
        let frame = document.frame
        ZStack(alignment: .topLeading) {
            BackgroundView(background: frame.background)
                .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)
            imageLayer(layout)
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)
        .clipped()
    }

    private func imageLayer(_ layout: CanvasLayout) -> some View {
        let size = document.imageSize
        let frame = document.frame
        // Shadow 0…100 → radius up to ~6 % of the canvas, opacity 0.2…0.6.
        let strength = max(0, min(frame.shadow, 100)) / 100
        let shadowRadius = strength * min(layout.canvasSize.width, layout.canvasSize.height) * 0.06
        return ZStack(alignment: .topLeading) {
            Image(decorative: document.baseImage, scale: 1)
                .resizable()
                .frame(width: size.width, height: size.height)
            ForEach(document.annotations) { annotation in
                AnnotationView(annotation: annotation, onTextMeasured: isExport ? nil : { size in
                    remember(size, for: annotation)
                })
                .opacity(annotation.id == hiddenAnnotationID ? 0 : 1)
            }
        }
        .frame(width: size.width, height: size.height)
        .scaleEffect(layout.imageScale, anchor: .topLeading)
        .frame(width: layout.imageRect.width, height: layout.imageRect.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: frame.cornerRadius))
        .shadow(color: .black.opacity(strength > 0 ? 0.2 + 0.4 * strength : 0), radius: shadowRadius, y: shadowRadius / 3)
        .offset(x: layout.imageRect.minX, y: layout.imageRect.minY)
    }

    private func remember(_ size: CGSize, for annotation: Annotation) {
        guard var current = document.annotation(id: annotation.id),
              case .text(var content) = current.kind, content.measuredSize != size else { return }
        content.measuredSize = size
        current.kind = .text(content)
        document.update(current)
    }
}

