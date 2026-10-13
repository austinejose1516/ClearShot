import ScreenshotXXCore
import SwiftUI

/// The picture itself: base image plus annotations, at 1 pt = 1 image pixel.
/// Used on screen (scaled by the canvas) and for export (rendered at scale 1), so both match.
struct CompositionView: View {
    let document: EditorDocument
    /// The text being edited inline is drawn by the editing field instead.
    var hiddenAnnotationID: Annotation.ID? = nil
    var isExport = false

    var body: some View {
        let size = document.imageSize
        ZStack(alignment: .topLeading) {
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
        .clipped()
    }

    private func remember(_ size: CGSize, for annotation: Annotation) {
        guard var current = document.annotation(id: annotation.id),
              case .text(var content) = current.kind, content.measuredSize != size else { return }
        content.measuredSize = size
        current.kind = .text(content)
        document.update(current)
        DiagnosticLog.write("text measured \(Int(size.width))x\(Int(size.height)) for \(content.text.prefix(8))")
    }
}
