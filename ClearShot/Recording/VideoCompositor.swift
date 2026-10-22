import AVFoundation
import CoreImage

/// Hands the composer to the compositor: AVFoundation makes the compositor itself, so the instruction is how
/// it finds what to draw.
nonisolated final class VideoComposerInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    let trackID: CMPersistentTrackID
    let composer: VideoComposer

    init(timeRange: CMTimeRange, trackID: CMPersistentTrackID, composer: VideoComposer) {
        self.timeRange = timeRange
        self.trackID = trackID
        self.composer = composer
        requiredSourceTrackIDs = [NSNumber(value: trackID)]
    }
}

/// Draws every frame of a composition through its instruction's `VideoComposer`: the player and the exporter
/// both go through here, so what you see is what is written.
nonisolated final class VideoCompositor: NSObject, AVVideoCompositing {
    private static let bgra: [String: any Sendable] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

    var sourcePixelBufferAttributes: [String: any Sendable]? { Self.bgra }
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] { Self.bgra }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? VideoComposerInstruction,
              let source = request.sourceFrame(byTrackID: instruction.trackID),
              let output = request.renderContext.newPixelBuffer() else {
            return request.finish(with: VideoExporter.Failure.step("draw a frame"))
        }
        let canvas = request.renderContext.size
        let image = instruction.composer.render(CIImage(cvPixelBuffer: source), canvas: canvas)
        VideoComposer.context.render(image, to: output, bounds: CGRect(origin: .zero, size: canvas),
                                     colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        request.finish(withComposedVideoFrame: output)
    }

    func cancelAllPendingVideoCompositionRequests() {}
}
