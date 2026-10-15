import AVFoundation
import ClearShotCore

/// After Stop: the pieces of a recording (one per run between pauses) become one small file. Runs off the main
/// actor.
nonisolated enum RecordingFinisher {
    /// Pieces shorter than this (a Pause right after Resume) are left out.
    private static let shortestPiece = 0.05

    /// Joins the pieces in order and re-encodes them into `destination` at our bitrate. Returns the length.
    @discardableResult
    static func save(pieces: [URL], encoding: VideoEncoding.Settings, to destination: URL,
                     progress: @escaping @Sendable (Double) -> Void) async throws -> Double {
        let asset = try await joined(pieces)
        let total = try await CMTimeGetSeconds(asset.load(.duration))
        guard total > 0 else { throw VideoExporter.Failure.noVideoTrack }
        try await VideoExporter.export(from: asset, range: .whole(total: total), encoding: encoding, to: destination, progress: progress)
        return total
    }

    /// The length of all the pieces together.
    static func duration(of pieces: [URL]) async -> Double {
        var total = 0.0
        for url in pieces {
            let seconds = (try? await CMTimeGetSeconds(AVURLAsset(url: url).load(.duration))) ?? 0
            if seconds >= shortestPiece { total += seconds }
        }
        return total
    }

    /// The first frame, small enough for a card.
    static func poster(of url: URL) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 960, height: 960)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        return try? await generator.image(at: .zero).image
    }

    /// One piece is used as it is; more become a composition that plays them back to back.
    private static func joined(_ pieces: [URL]) async throws -> AVAsset {
        if pieces.count == 1 { return AVURLAsset(url: pieces[0]) }
        let composition = AVMutableComposition()
        var cursor = CMTime.zero
        for url in pieces {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            guard CMTimeGetSeconds(duration) >= shortestPiece else { continue }
            try await composition.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: asset, at: cursor)
            cursor = cursor + duration
        }
        return composition
    }
}
