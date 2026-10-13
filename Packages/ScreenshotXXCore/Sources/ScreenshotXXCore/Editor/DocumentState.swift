import CoreGraphics

/// Everything undo/redo tracks, including the base image (crop replaces it). A value type, so snapshots are safe.
public struct DocumentState: Equatable, Sendable {
    public var baseImage: CGImage
    public var annotations: [Annotation] = []
    public var frame = FrameStyle()

    public init(baseImage: CGImage) {
        self.baseImage = baseImage
    }

    public static func == (lhs: DocumentState, rhs: DocumentState) -> Bool {
        lhs.baseImage === rhs.baseImage && lhs.annotations == rhs.annotations && lhs.frame == rhs.frame
    }
}
