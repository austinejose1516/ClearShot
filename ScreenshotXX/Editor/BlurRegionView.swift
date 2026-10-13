import CoreImage
import CoreImage.CIFilterBuiltins
import ScreenshotXXCore
import SwiftUI

/// The base image under `rect`, pixelated or blurred, drawn back at the same place.
struct BlurRegionView: View {
    let base: CGImage
    let rect: CGRect
    let mode: BlurMode

    var body: some View {
        let area = BlurRenderer.clamp(rect, to: base)
        if let image = BlurRenderer.render(base: base, area: area, mode: mode) {
            Image(decorative: image, scale: 1)
                .resizable()
                .frame(width: area.width, height: area.height)
                .offset(x: area.minX, y: area.minY)
        }
    }
}

enum BlurRenderer {
    private struct Key: Hashable {
        let base: ObjectIdentifier
        let area: CGRect
        let mode: BlurMode
    }

    /// Each entry keeps its base image alive, so the image's identity cannot be reused by a new image.
    private static var cache: [Key: (base: CGImage, output: CGImage)] = [:]
    private static let context = CIContext()

    static func clamp(_ rect: CGRect, to base: CGImage) -> CGRect {
        rect.standardized.integral.intersection(CGRect(x: 0, y: 0, width: base.width, height: base.height))
    }

    static func render(base: CGImage, area: CGRect, mode: BlurMode) -> CGImage? {
        guard area.width >= 2, area.height >= 2 else { return nil }
        let key = Key(base: ObjectIdentifier(base), area: area, mode: mode)
        if let hit = cache[key] { return hit.output }
        guard let crop = base.cropping(to: area) else { return nil }
        let input = CIImage(cgImage: crop)
        let output: CIImage?
        switch mode {
        case .pixelate:
            let filter = CIFilter.pixellate()
            filter.inputImage = input
            filter.scale = Float(max(12, min(area.width, area.height) / 12))
            filter.center = CGPoint(x: area.width / 2, y: area.height / 2)
            output = filter.outputImage?.cropped(to: input.extent)
        case .blur:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = input.clampedToExtent()
            filter.radius = Float(max(10, min(area.width, area.height) / 10))
            output = filter.outputImage?.cropped(to: input.extent)
        }
        guard let output, let rendered = context.createCGImage(output, from: input.extent) else { return nil }
        if cache.count > 64 { cache.removeAll() }
        cache[key] = (base, rendered)
        return rendered
    }
}
