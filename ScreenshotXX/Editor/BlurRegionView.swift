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
        if let image = BlurRenderer.render(base: base, rect: rect, mode: mode) {
            let r = BlurRenderer.clamp(rect, to: base)
            Image(decorative: image, scale: 1)
                .resizable()
                .frame(width: r.width, height: r.height)
                .offset(x: r.minX, y: r.minY)
        }
    }
}

enum BlurRenderer {
    private static var cache: [String: CGImage] = [:]
    private static let context = CIContext()

    static func clamp(_ rect: CGRect, to base: CGImage) -> CGRect {
        rect.standardized.integral.intersection(CGRect(x: 0, y: 0, width: base.width, height: base.height))
    }

    static func render(base: CGImage, rect: CGRect, mode: BlurMode) -> CGImage? {
        let r = clamp(rect, to: base)
        guard r.width >= 2, r.height >= 2 else { return nil }
        let key = "\(ObjectIdentifier(base).hashValue)|\(r)|\(mode.rawValue)"
        if let cached = cache[key] { return cached }
        guard let crop = base.cropping(to: r) else { return nil }
        let input = CIImage(cgImage: crop)
        let output: CIImage?
        switch mode {
        case .pixelate:
            let filter = CIFilter.pixellate()
            filter.inputImage = input
            filter.scale = Float(max(12, min(r.width, r.height) / 12))
            filter.center = CGPoint(x: r.width / 2, y: r.height / 2)
            output = filter.outputImage?.cropped(to: input.extent)
        case .blur:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = input.clampedToExtent()
            filter.radius = Float(max(10, min(r.width, r.height) / 10))
            output = filter.outputImage?.cropped(to: input.extent)
        }
        guard let output, let rendered = context.createCGImage(output, from: input.extent) else { return nil }
        if cache.count > 64 { cache.removeAll() }
        cache[key] = rendered
        return rendered
    }
}
