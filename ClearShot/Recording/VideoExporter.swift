import AVFoundation
import ClearShotCore
import Synchronization

/// Trims and re-encodes a recording (one file, or the pieces of a paused recording joined): H.264 at the
/// bitrate from Settings, every audio track mixed into one AAC track. Runs off the main actor; `progress` is
/// called from the encoder's thread.
nonisolated enum VideoExporter {
    enum Failure: LocalizedError {
        case noVideoTrack
        case step(String)

        var errorDescription: String? {
            switch self {
            case .noVideoTrack: "The recording has no video in it."
            case .step(let what): "Could not \(what)."
            }
        }
    }

    static func export(from asset: AVAsset, range: TrimRange, encoding: VideoEncoding.Settings, to destination: URL,
                       progress: @escaping @Sendable (Double) -> Void) async throws {
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else { throw Failure.noVideoTrack }
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let start = CMTime(seconds: range.start, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: start, duration: CMTime(seconds: range.duration, preferredTimescale: 600))

        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = timeRange
        let videoOutput = AVAssetReaderTrackOutput(
            track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        videoOutput.alwaysCopiesSampleData = false
        reader.add(videoOutput)
        // One output over every audio track: the mix output sums them (system sound and the microphone).
        let audioOutput = audioTracks.isEmpty ? nil : AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
        if let audioOutput { reader.add(audioOutput) }

        let partURL = destination.deletingLastPathComponent().appending(path: ".\(destination.lastPathComponent).part")
        try? FileManager.default.removeItem(at: partURL)
        let writer = try AVAssetWriter(outputURL: partURL, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true   // the index first, so a browser (or the Uploads window) starts at once
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings(encoding))
        videoInput.expectsMediaDataInRealTime = false
        writer.add(videoInput)
        let audioInput = audioOutput == nil ? nil : AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings(encoding))
        if let audioInput {
            audioInput.expectsMediaDataInRealTime = false
            writer.add(audioInput)
        }

        guard reader.startReading() else { throw reader.error ?? Failure.step("read the recording") }
        guard writer.startWriting() else { throw writer.error ?? Failure.step("start the new file") }
        writer.startSession(atSourceTime: start)

        let stop = StopFlag()
        let duration = range.duration
        let startSeconds = range.start
        let videoPump = Pump(label: "video", output: videoOutput, input: videoInput, stop: stop)
        var audioPump: Pump?
        if let audioOutput, let audioInput {
            audioPump = Pump(label: "audio", output: audioOutput, input: audioInput, stop: stop)
        }
        await withTaskCancellationHandler { [audioPump] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await videoPump.run { time in
                        guard duration > 0 else { return }
                        progress(min(1, max(0, (CMTimeGetSeconds(time) - startSeconds) / duration)))
                    }
                }
                if let audioPump {
                    group.addTask { await audioPump.run { _ in } }
                }
            }
        } onCancel: {
            stop.raise()
        }

        if stop.isRaised {
            reader.cancelReading()
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: partURL)
            throw CancellationError()
        }
        guard reader.status != .failed else {
            writer.cancelWriting()
            throw reader.error ?? Failure.step("read the recording")
        }
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? Failure.step("write the new file") }
        if FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: partURL)
        } else {
            try FileManager.default.moveItem(at: partURL, to: destination)
        }
    }

    private static func videoSettings(_ encoding: VideoEncoding.Settings) -> [String: Any] {
        [AVVideoCodecKey: AVVideoCodecType.h264,
         AVVideoWidthKey: encoding.width,
         AVVideoHeightKey: encoding.height,
         AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: encoding.videoBitrate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoMaxKeyFrameIntervalDurationKey: 2,
            AVVideoExpectedSourceFrameRateKey: encoding.fps,
         ]]
    }

    private static func audioSettings(_ encoding: VideoEncoding.Settings) -> [String: Any] {
        [AVFormatIDKey: kAudioFormatMPEG4AAC,
         AVSampleRateKey: 48_000,
         AVNumberOfChannelsKey: 2,
         AVEncoderBitRateKey: encoding.audioBitrate]
    }
}

/// Moves samples from one reader output into one writer input, as fast as the writer takes them.
nonisolated private final class Pump: @unchecked Sendable {
    private let output: AVAssetReaderOutput
    private let input: AVAssetWriterInput
    private let stop: StopFlag
    private let queue: DispatchQueue
    private let finished = Mutex(false)

    init(label: String, output: AVAssetReaderOutput, input: AVAssetWriterInput, stop: StopFlag) {
        self.output = output
        self.input = input
        self.stop = stop
        queue = DispatchQueue(label: "com.austinejose.clearshot.export.\(label)")
    }

    func run(onSample: @escaping @Sendable (CMTime) -> Void) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            input.requestMediaDataWhenReady(on: queue) { [self] in
                while input.isReadyForMoreMediaData {
                    if stop.isRaised { return finish(continuation) }
                    guard let sample = output.copyNextSampleBuffer() else { return finish(continuation) }
                    // A refused sample means the writer failed; its status says why, once everything is done.
                    guard input.append(sample) else { return finish(continuation) }
                    onSample(CMSampleBufferGetPresentationTimeStamp(sample))
                }
            }
        }
    }

    private func finish(_ continuation: CheckedContinuation<Void, Never>) {
        let first = finished.withLock { done in
            defer { done = true }
            return !done
        }
        guard first else { return }
        input.markAsFinished()
        continuation.resume()
    }
}

/// A flag the pumps poll: set when the export is cancelled.
nonisolated private final class StopFlag: Sendable {
    private let raised = Mutex(false)

    func raise() { raised.withLock { $0 = true } }
    var isRaised: Bool { raised.withLock { $0 } }
}
