/// Everything undo/redo tracks. A value type, so snapshots are free of aliasing bugs.
public struct DocumentState: Equatable, Sendable, Codable {
    public var annotations: [Annotation] = []
    public var frame = FrameStyle()

    public init() {}
}
