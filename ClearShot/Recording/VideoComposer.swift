import AVFoundation
import ClearShotCore
import CoreImage
import CoreImage.CIFilterBuiltins
import Synchronization

/// What the compositor draws on every frame: the blur boxes on the video, then the video on its frame
/// (background, padding, rounded corners, shadow). Shared between the editor, which changes it as you edit, and
/// the compositor's thread, which reads the latest on every frame. The exporter gets its own, fixed one.
nonisolated final class VideoComposer: Sendable {
    struct Edits: Equatable, Sendable {
        var blurs: VideoBlurs
        var frame: FrameStyle

        var isEmpty: Bool { blurs.isEmpty && frame == FrameStyle() }
    }

    /// The background and the shadow, drawn once per frame style and size, plus the rounded mask the video
    /// shows through. The plate is rendered to pixels so the shadow's blur is not computed again per frame.
    private struct Plate {
        let frame: FrameStyle
        let canvas: CGSize
        let image: CIImage
        let mask: CIImage
    }

    /// One context for every composer and compositor; Core Image contexts are safe to share.
    static let context = CIContext(options: [.cacheIntermediates: false])

    private let state: Mutex<(edits: Edits, plate: Plate?)>

    init(blurs: VideoBlurs, frame: FrameStyle) {
        state = Mutex((Edits(blurs: blurs, frame: frame), nil))
    }

    var edits: Edits { state.withLock { $0.edits } }

    func update(blurs: VideoBlurs, frame: FrameStyle) {
        state.withLock { $0.edits = Edits(blurs: blurs, frame: frame) }
    }

    /// A composition that draws every frame of `asset` through `VideoCompositor`, `renderSize` big.
    static func composition(for asset: AVAsset, composer: VideoComposer, renderSize: CGSize) async throws -> AVVideoComposition {
        // AVAsset is safe to read from any thread; the compiler cannot see that across the async calls.
        nonisolated(unsafe) let asset = asset
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw VideoExporter.Failure.noVideoTrack }
        let duration = try await asset.load(.duration)
        var configuration = try await AVVideoComposition.Configuration(for: asset)
        configuration.customVideoCompositorClass = VideoCompositor.self
        configuration.renderSize = renderSize
        configuration.instructions = [VideoComposerInstruction(timeRange: CMTimeRange(start: .zero, duration: duration),
                                                               trackID: track.trackID, composer: composer)]
        return AVVideoComposition(configuration: configuration)
    }

    // MARK: - One frame

    /// The boxes on the source, then the source centred on the plate through the rounded mask. `canvas` is the
    /// output size; without a frame it is the source's own size and the source comes back as it is.
    func render(_ source: CIImage, canvas: CGSize) -> CIImage {
        let edits = edits
        let hidden = Self.blurred(source, blurs: edits.blurs)
        guard edits.frame != FrameStyle() else { return hidden }
        let plate = plate(for: edits.frame, canvas: canvas, video: source.extent.size)
        let placed = hidden.transformed(by: CGAffineTransform(
            translationX: (canvas.width - source.extent.width) / 2 - source.extent.minX,
            y: (canvas.height - source.extent.height) / 2 - source.extent.minY))
        let blend = CIFilter.blendWithMask()
        blend.inputImage = placed
        blend.backgroundImage = plate.image
        blend.maskImage = plate.mask
        return (blend.outputImage ?? placed).cropped(to: CGRect(origin: .zero, size: canvas))
    }

    /// Each box's crop, blurred or pixelated, over the frame. Boxes are in video pixels from the top-left;
    /// Core Image counts from the bottom-left, and the frame may not be the box's frame size (an old file).
    static func blurred(_ source: CIImage, blurs: VideoBlurs) -> CIImage {
        guard !blurs.isEmpty, blurs.frame.width > 0, blurs.frame.height > 0 else { return source }
        let extent = source.extent
        let sx = extent.width / blurs.frame.width, sy = extent.height / blurs.frame.height
        var output = source
        for region in blurs.regions {
            let r = region.rect
            let area = CGRect(x: extent.minX + r.minX * sx, y: extent.minY + (blurs.frame.height - r.maxY) * sy,
                              width: r.width * sx, height: r.height * sy)
                .integral.intersection(extent)
            guard area.width >= 1, area.height >= 1,
                  let hidden = BlurFilters.hidden(source, area: area, mode: region.mode) else { continue }
            output = hidden.composited(over: output)
        }
        return output
    }

    // MARK: - The plate

    private func plate(for frame: FrameStyle, canvas: CGSize, video: CGSize) -> Plate {
        if let cached = state.withLock({ $0.plate }), cached.frame == frame, cached.canvas == canvas { return cached }
        let built = Self.makePlate(frame: frame, canvas: canvas, video: video)
        state.withLock { $0.plate = built }
        return built
    }

    private static func makePlate(frame: FrameStyle, canvas: CGSize, video: CGSize) -> Plate {
        let bounds = CGRect(origin: .zero, size: canvas)
        let videoRect = CGRect(x: (canvas.width - video.width) / 2, y: (canvas.height - video.height) / 2,
                               width: video.width, height: video.height)
        var image = background(frame.background, in: bounds)
        let radius = frame.shadowRadius(canvasSize: canvas)
        if frame.shadowOpacity > 0, radius > 0 {
            let shape = roundedRectangle(videoRect, radius: frame.cornerRadius,
                                         color: CIColor(red: 0, green: 0, blue: 0, alpha: frame.shadowOpacity))
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = shape
            blur.radius = Float(radius)
            // Down by a third of the radius, like the screenshot editor; Core Image's y goes up.
            if let shadow = blur.outputImage?.transformed(by: CGAffineTransform(translationX: 0, y: -radius / 3)) {
                image = shadow.composited(over: image)
            }
        }
        // Rendered once: a CIImage is a recipe, and the blur would otherwise run again on every frame.
        if let pixels = context.createCGImage(image.cropped(to: bounds), from: bounds) {
            image = CIImage(cgImage: pixels)
        }
        let mask = roundedRectangle(videoRect, radius: frame.cornerRadius, color: .white)
        return Plate(frame: frame, canvas: canvas, image: image, mask: mask)
    }

    private static func roundedRectangle(_ rect: CGRect, radius: CGFloat, color: CIColor) -> CIImage {
        let generator = CIFilter.roundedRectangleGenerator()
        generator.extent = rect
        generator.radius = Float(max(0, min(radius, min(rect.width, rect.height) / 2)))
        generator.color = color
        return generator.outputImage ?? CIImage(color: color).cropped(to: rect)
    }

    /// None is black: a video has no see-through. The gradient runs top-left to bottom-right, as on screenshots.
    private static func background(_ background: Background, in bounds: CGRect) -> CIImage {
        switch background {
        case .none:
            return CIImage(color: .black).cropped(to: bounds)
        case .solid(let colour):
            return CIImage(color: CIColor(red: colour.red, green: colour.green, blue: colour.blue)).cropped(to: bounds)
        case .gradient(let preset):
            let gradient = CIFilter.linearGradient()
            gradient.point0 = CGPoint(x: 0, y: bounds.height)
            gradient.point1 = CGPoint(x: bounds.width, y: 0)
            gradient.color0 = CIColor(red: preset.start.red, green: preset.start.green, blue: preset.start.blue)
            gradient.color1 = CIColor(red: preset.end.red, green: preset.end.green, blue: preset.end.blue)
            return (gradient.outputImage ?? CIImage(color: .black)).cropped(to: bounds)
        case .image(let url):
            guard let picture = CIImage(contentsOf: url), picture.extent.width > 0, picture.extent.height > 0 else {
                return CIImage(color: .gray).cropped(to: bounds)
            }
            let scale = max(bounds.width / picture.extent.width, bounds.height / picture.extent.height)
            let scaled = picture.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let centred = scaled.transformed(by: CGAffineTransform(
                translationX: (bounds.width - scaled.extent.width) / 2 - scaled.extent.minX,
                y: (bounds.height - scaled.extent.height) / 2 - scaled.extent.minY))
            return centred.cropped(to: bounds)
        }
    }
}
