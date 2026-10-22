import AVFoundation
import ClearShotCore
import CoreImage
import Synchronization

/// The blur boxes as an `AVVideoComposition`, so the player shows them live and the exporter writes them
/// through the same Core Image handler. The boxes can change while the player uses it: the handler reads the
/// latest ones on every frame.
nonisolated final class VideoBlurComposition: Sendable {
    private let box: Mutex<VideoBlurs>

    init(blurs: VideoBlurs) {
        box = Mutex(blurs)
    }

    var blurs: VideoBlurs { box.withLock { $0 } }

    func update(_ blurs: VideoBlurs) {
        box.withLock { $0 = blurs }
    }

    func composition(for asset: AVAsset) async throws -> AVVideoComposition {
        // AVAsset is safe to read from any thread; the compiler cannot see that across the async call.
        nonisolated(unsafe) let asset = asset
        return try await AVVideoComposition(applyingFiltersTo: asset) { parameters in
            AVCIImageFilteringResult(resultImage: Self.frame(parameters.sourceImage, blurs: self.blurs), ciContext: nil)
        }
    }

    /// Each box's crop, blurred or pixelated, over the frame. Boxes are in video pixels from the top-left;
    /// Core Image counts from the bottom-left, and the frame may not be the box's frame size (an old file).
    static func frame(_ source: CIImage, blurs: VideoBlurs) -> CIImage {
        guard blurs.frame.width > 0, blurs.frame.height > 0 else { return source }
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
}
