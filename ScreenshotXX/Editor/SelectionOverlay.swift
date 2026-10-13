import ScreenshotXXCore
import SwiftUI

/// Dashed bounds and dots for the selected annotations, drawn in zoomed space so they keep a constant size.
struct SelectionOverlay: View {
    let document: EditorDocument
    let transform: CanvasTransform
    var hiddenID: Annotation.ID? = nil

    var body: some View {
        ForEach(document.annotations.filter { document.selection.contains($0.id) && $0.id != hiddenID }) { annotation in
            let bounds = transform.toCanvas(annotation.bounds)
            Rectangle()
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: max(1, bounds.width), height: max(1, bounds.height))
                .offset(x: bounds.minX, y: bounds.minY)
            ForEach(annotation.handles, id: \.kind) { handle in
                let point = transform.toCanvas(handle.point)
                Circle()
                    .fill(.white)
                    .stroke(Color.accentColor, lineWidth: 1.5)
                    .frame(width: 10, height: 10)
                    .offset(x: point.x - 5, y: point.y - 5)
            }
        }
        .allowsHitTesting(false)
    }
}
