import ScreenshotXXCore
import SwiftUI

/// The picture itself: base image plus annotations, at 1 pt = 1 image pixel.
/// Used on screen (scaled by the canvas) and for export (rendered at scale 1), so both match.
struct CompositionView: View {
    let document: EditorDocument

    var body: some View {
        let size = document.imageSize
        ZStack(alignment: .topLeading) {
            Image(decorative: document.baseImage, scale: 1)
                .resizable()
                .frame(width: size.width, height: size.height)
            ForEach(document.annotations) { annotation in
                AnnotationView(annotation: annotation)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}
