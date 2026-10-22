import AVFoundation
import ClearShotCore
import ImageIO

/// A small picture of an uploaded file, read from its public link every time the Uploads window opens.
/// Nothing is written to disk: the session has no cache, and the pictures live only in `UploadsModel`.
nonisolated enum RemoteThumbnail {
    /// The longest side of a thumbnail, in pixels.
    static let maxPixelSize = 512

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }()

    static func load(_ item: UploadedItem, from link: URL) async -> CGImage? {
        switch item.kind {
        case .image: await image(from: link)
        case .video: await firstFrame(of: link)
        }
    }

    /// The whole file is fetched, then made small with ImageIO before it is kept.
    private static func image(from link: URL) async -> CGImage? {
        guard let (data, response) = try? await session.data(from: link),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// AVFoundation reads only the bytes it needs for the first frame (the index and one keyframe).
    private static func firstFrame(of link: URL) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: link))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        return try? await generator.image(at: .zero).image
    }
}
