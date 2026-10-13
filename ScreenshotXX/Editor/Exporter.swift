import ScreenshotXXCore
import SwiftUI

enum Exporter {
    /// Renders the composition at scale 1, so the output has the canvas's pixel size.
    static func render(_ document: EditorDocument) -> CGImage? {
        let renderer = ImageRenderer(content: CompositionView(document: document))
        renderer.scale = 1
        renderer.isOpaque = false
        return renderer.cgImage
    }
}
