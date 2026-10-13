import ClearShotCore
import SwiftUI

/// Image pixels ↔ zoomed canvas points (what the user sees).
struct CanvasTransform {
    let scale: CGFloat
    let offset: CGPoint

    init(layout: CanvasLayout, zoom: CGFloat) {
        scale = zoom
        offset = CGPoint(x: layout.imageRect.minX * zoom, y: layout.imageRect.minY * zoom)
    }

    func toCanvas(_ point: CGPoint) -> CGPoint {
        CGPoint(x: offset.x + point.x * scale, y: offset.y + point.y * scale)
    }

    func fromCanvas(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - offset.x) / scale, y: (point.y - offset.y) / scale)
    }

    func toCanvas(_ rect: CGRect) -> CGRect {
        let origin = toCanvas(rect.origin)
        return CGRect(x: origin.x, y: origin.y, width: rect.width * scale, height: rect.height * scale)
    }
}
