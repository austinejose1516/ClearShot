import CoreImage
import CoreImage.CIFilterBuiltins
import ClearShotCore
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

/// The two ways to hide part of a picture, shared by the screenshot editor and the video editor.
nonisolated enum BlurFilters {
    /// `area` is in the input's own coordinates (origin bottom-left); the result is cropped to it.
    static func hidden(_ input: CIImage, area: CGRect, mode: BlurMode) -> CIImage? {
        let crop = input.cropped(to: area)
        switch mode {
        case .pixelate:
            let filter = CIFilter.pixellate()
            filter.inputImage = crop
            filter.scale = Float(max(12, min(area.width, area.height) / 12))
            filter.center = CGPoint(x: area.midX, y: area.midY)
            return filter.outputImage?.cropped(to: area)
        case .blur:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = crop.clampedToExtent()
            filter.radius = Float(max(10, min(area.width, area.height) / 10))
            return filter.outputImage?.cropped(to: area)
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
        guard let output = BlurFilters.hidden(input, area: input.extent, mode: mode),
              let rendered = context.createCGImage(output, from: input.extent) else { return nil }
        if cache.count > 64 { cache.removeAll() }
        cache[key] = (base, rendered)
        return rendered
    }
}
