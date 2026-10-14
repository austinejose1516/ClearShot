/// The part of a recording to keep, in seconds. The handles never cross and never leave the recording.
public struct TrimRange: Equatable, Sendable {
    /// The shortest clip the handles allow, so there is always something to play.
    public static let minimumLength: Double = 0.5

    public private(set) var start: Double
    public private(set) var end: Double
    /// The recording's full length.
    public let total: Double

    public init(start: Double, end: Double, total: Double) {
        self.total = max(0, total)
        self.start = min(max(0, start), self.total)
        self.end = min(max(self.start, end), self.total)
    }

    public static func whole(total: Double) -> TrimRange {
        TrimRange(start: 0, end: total, total: total)
    }

    public var duration: Double { end - start }
    public var isWhole: Bool { start == 0 && end == total }

    public func movingStart(to value: Double) -> TrimRange {
        var range = self
        range.start = max(0, min(value, end - Self.minimumLength))
        return range
    }

    public func movingEnd(to value: Double) -> TrimRange {
        var range = self
        range.end = min(total, max(value, start + Self.minimumLength))
        return range
    }
}
