import Foundation

/// How long a recording has run, leaving out the paused parts. The recording bar shows it.
public struct RecordingClock: Equatable, Sendable {
    private var runningSince: Date?
    /// Time recorded before the current run (every finished run added up).
    private var banked: TimeInterval = 0

    public init(startedAt: Date) {
        runningSince = startedAt
    }

    public var isPaused: Bool { runningSince == nil }

    public mutating func pause(at date: Date) {
        guard let runningSince else { return }
        banked += max(0, date.timeIntervalSince(runningSince))
        self.runningSince = nil
    }

    public mutating func resume(at date: Date) {
        guard runningSince == nil else { return }
        runningSince = date
    }

    public func elapsed(at date: Date) -> TimeInterval {
        banked + (runningSince.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }
}
