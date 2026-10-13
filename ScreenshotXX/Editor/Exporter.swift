import ScreenshotXXCore
import SwiftUI

enum Exporter {
    /// Renders the composition at scale 1, so the output has the base image's pixel size.
    static func render(_ document: EditorDocument) -> CGImage? {
        let renderer = ImageRenderer(content: CompositionView(document: document, isExport: true))
        renderer.scale = 1
        renderer.isOpaque = false
        return renderer.cgImage
    }
}
