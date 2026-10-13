import ScreenshotXXCore
import SwiftUI

/// The export canvas: background, then the image with its annotations, at 1 pt = 1 canvas pixel.
/// Used on screen (scaled by the canvas) and for export (scale 1), so both match.
struct CompositionView: View {
    let document: EditorDocument
    /// The text being edited is drawn by the inline editor instead.
    var hiddenAnnotationID: Annotation.ID? = nil

    var body: some View {
        let layout = document.layout
        let frame = document.frame
        // Shadow 0…100 → radius up to ~6 % of the canvas, opacity 0.2…0.6.
        let strength = max(0, min(frame.shadow, 100)) / 100
        let shadowRadius = strength * min(layout.canvasSize.width, layout.canvasSize.height) * 0.06
        ZStack(alignment: .topLeading) {
            BackgroundView(background: frame.background)
                .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)
            ZStack(alignment: .topLeading) {
                Image(decorative: document.baseImage, scale: 1)
                    .resizable()
                    .frame(width: layout.imageSize.width, height: layout.imageSize.height)
                ForEach(document.annotations) { annotation in
                    AnnotationView(annotation: annotation, baseImage: document.baseImage)
                        .opacity(annotation.id == hiddenAnnotationID ? 0 : 1)
                }
            }
            .frame(width: layout.imageSize.width, height: layout.imageSize.height, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: frame.cornerRadius))
            .shadow(color: .black.opacity(strength > 0 ? 0.2 + 0.4 * strength : 0), radius: shadowRadius, y: shadowRadius / 3)
            .offset(x: layout.imageRect.minX, y: layout.imageRect.minY)
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)
        .clipped()
    }
}
