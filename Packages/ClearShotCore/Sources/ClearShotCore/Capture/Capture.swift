import CoreGraphics
import Foundation

public struct Capture: Identifiable, Sendable {
    public let id: UUID
    public let kind: CaptureKind
    public let createdAt: Date
    /// What is saved and copied. A window capture includes the system shadow.
    public private(set) var image: CGImage
    /// A window capture's window alone, without the shadow.
    public private(set) var windowImage: CGImage?
    public var fileURL: URL?
    /// How many screens tall a scrolling capture is (1 for everything else). The file size budget grows with it.
    public let pageCount: Int
    /// Set for a screen recording: then `image` is its first frame and the file is an mp4.
    public private(set) var video: Video?

    /// A recording's length and the size it was encoded at (the editor re-encodes a trim the same way).
    public struct Video: Equatable, Sendable {
        public let duration: Double
        public let encoding: VideoEncoding.Settings

        public init(duration: Double, encoding: VideoEncoding.Settings) {
            self.duration = duration
            self.encoding = encoding
        }
    }

    public init(kind: CaptureKind, image: CGImage, windowImage: CGImage? = nil, createdAt: Date = .now, fileURL: URL? = nil,
                pageCount: Int = 1, video: Video? = nil) {
        self.id = UUID()
        self.kind = kind
        self.createdAt = createdAt
        self.image = image
        self.windowImage = windowImage
        self.fileURL = fileURL
        self.pageCount = max(1, pageCount)
        self.video = video
    }

    public var isVideo: Bool { video != nil }

    /// The editor is done: the card shows, copies and saves this from now on, and it is the new starting point
    /// (the bare window is not).
    public mutating func edited(image: CGImage) {
        self.image = image
        windowImage = nil
    }

    /// The video editor saved: a new length and first frame, and a new size when a frame was added.
    public mutating func saved(videoDuration: Double, poster: CGImage, encoding: VideoEncoding.Settings? = nil, at url: URL) {
        if let video { self.video = Video(duration: videoDuration, encoding: encoding ?? video.encoding) }
        image = poster
        fileURL = url
    }

    /// The editor starts from the window alone, so corners, padding and shadow act on the window itself.
    public var editorImage: CGImage { windowImage ?? image }

    public var editorFrame: FrameStyle {
        guard let windowImage else { return FrameStyle() }
        return .windowShadow(margin: max(0, CGFloat(image.width - windowImage.width) / 2),
                             imageSize: CGSize(width: windowImage.width, height: windowImage.height))
    }
}
