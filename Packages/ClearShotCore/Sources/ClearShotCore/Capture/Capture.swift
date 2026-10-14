import CoreGraphics
import Foundation

public struct Capture: Identifiable, Sendable {
    public let id: UUID
    public let kind: CaptureKind
    public let createdAt: Date
    /// What is saved and copied. A window capture includes the system shadow.
    public let image: CGImage
    /// A window capture's window alone, without the shadow.
    public let windowImage: CGImage?
    public var fileURL: URL?
    /// How many screens tall a scrolling capture is (1 for everything else). The file size budget grows with it.
    public let pageCount: Int

    public init(kind: CaptureKind, image: CGImage, windowImage: CGImage? = nil, createdAt: Date = .now, fileURL: URL? = nil, pageCount: Int = 1) {
        self.id = UUID()
        self.kind = kind
        self.createdAt = createdAt
        self.image = image
        self.windowImage = windowImage
        self.fileURL = fileURL
        self.pageCount = max(1, pageCount)
    }

    /// The editor starts from the window alone, so corners, padding and shadow act on the window itself.
    public var editorImage: CGImage { windowImage ?? image }

    public var editorFrame: FrameStyle {
        guard let windowImage else { return FrameStyle() }
        return .windowShadow(margin: max(0, CGFloat(image.width - windowImage.width) / 2),
                             imageSize: CGSize(width: windowImage.width, height: windowImage.height))
    }
}
