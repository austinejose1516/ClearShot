import CoreGraphics
import Foundation

public struct Capture: Identifiable, Sendable {
    public let id: UUID
    public let kind: CaptureKind
    public let createdAt: Date
    public let image: CGImage
    public var fileURL: URL?

    public init(kind: CaptureKind, image: CGImage, createdAt: Date = .now, fileURL: URL? = nil) {
        self.id = UUID()
        self.kind = kind
        self.createdAt = createdAt
        self.image = image
        self.fileURL = fileURL
    }
}
