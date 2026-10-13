import ScreenshotXXCore
import SwiftUI

/// The export canvas: background, the image, then annotations over the whole canvas (so text can sit in the
/// padding), at 1 pt = 1 canvas pixel.
/// Used on screen (scaled by the canvas) and for export (scale 1), so both match.
struct CompositionView: View {
    let document: EditorDocument
    /// The text being edited is drawn by the inline editor instead.
    var hiddenAnnotationID: Annotation.ID? = nil

    var body: some View {
        let layout = document.layout
        let frame = document.frame
        let shadowRadius = frame.shadowRadius(canvasSize: layout.canvasSize)
        ZStack(alignment: .topLeading) {
            BackgroundView(background: frame.background)
                .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)
            Image(decorative: document.baseImage, scale: 1)
                .resizable()
                .frame(width: layout.imageSize.width, height: layout.imageSize.height)
                .clipShape(RoundedRectangle(cornerRadius: frame.cornerRadius))
                .shadow(color: .black.opacity(frame.shadowOpacity), radius: shadowRadius, y: shadowRadius / 3)
                .offset(x: layout.imageRect.minX, y: layout.imageRect.minY)
            // Annotations use image coordinates; negative ones land in the padding. Not clipped to the image.
            ZStack(alignment: .topLeading) {
                ForEach(document.annotations) { annotation in
                    AnnotationView(annotation: annotation, baseImage: document.baseImage)
                        .opacity(annotation.id == hiddenAnnotationID ? 0 : 1)
                }
            }
            .frame(width: layout.imageSize.width, height: layout.imageSize.height, alignment: .topLeading)
            .offset(x: layout.imageRect.minX, y: layout.imageRect.minY)
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)
        .clipped()
    }
}
