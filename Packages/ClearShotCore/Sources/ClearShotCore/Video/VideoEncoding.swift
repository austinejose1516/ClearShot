import CoreGraphics
import Foundation

/// How big a recording is: the size it is encoded at and the bits the encoder may spend.
public enum VideoQuality: String, CaseIterable, Sendable, Codable {
    case smaller, better, retina

    public var title: String {
        switch self {
        case .smaller: "Smaller"
        case .better: "Better"
        case .retina: "Retina"
        }
    }

    /// Bits per pixel per frame. Screen content is mostly still, so the encoder spends far less most of the time.
    var bitsPerPixel: Double {
        switch self {
        case .smaller: 0.05
        case .better: 0.09
        case .retina: 0.07
        }
    }

    /// Smaller and Better record at 1x (one pixel per point); Retina keeps every pixel.
    var recordsAtRetina: Bool { self == .retina }
}

/// The numbers the recorder and the exporter use. Pure, so the sizes are testable.
public enum VideoEncoding {
    public static let fps = 30
    /// AAC, stereo, enough for speech and UI sounds.
    public static let audioBitrate = 96_000
    public static let minimumVideoBitrate = 1_000_000
    public static let maximumVideoBitrate = 20_000_000

    public struct Settings: Equatable, Sendable {
        public let width: Int
        public let height: Int
        public let fps: Int
        /// H.264 average bits per second.
        public let videoBitrate: Int
        public let audioBitrate: Int

        /// The most the file can be for this length; real files are smaller when the screen is still.
        public func estimatedBytes(seconds: Double) -> Int {
            Int((Double(videoBitrate + audioBitrate) * seconds / 8).rounded())
        }
    }

    /// `pixelSize` is the captured size in pixels and `scale` its points-to-pixels factor (2 on Retina).
    public static func settings(for pixelSize: CGSize, scale: CGFloat, quality: VideoQuality) -> Settings {
        let divisor = quality.recordsAtRetina ? 1 : max(1, scale)
        let width = even(pixelSize.width / divisor)
        let height = even(pixelSize.height / divisor)
        let wanted = Double(width * height * fps) * quality.bitsPerPixel
        let bitrate = min(max(Int(wanted.rounded()), minimumVideoBitrate), maximumVideoBitrate)
        return Settings(width: width, height: height, fps: fps, videoBitrate: bitrate, audioBitrate: audioBitrate)
    }

    /// Whole, even pixel counts: H.264 wants even sizes.
    static func even(_ value: CGFloat) -> Int {
        max(2, Int(value) / 2 * 2)
    }
}
