import Foundation

/// The rules of an automatic scrolling capture: how far to scroll each time and when to stop.
public enum ScrollPlanner {
    /// Each scroll moves this share of the region, so neighbouring frames overlap well.
    public static let stepFraction = 0.6
    /// The step is never smaller than this, in points.
    public static let minimumStep: Double = 20
    /// Two still frames in a row: the end of the page.
    public static let stillFramesToStop = 2
    /// Three frames in a row with no overlap: give up with what is there.
    public static let lostFramesToStop = 3
    /// How often to look while waiting for a scroll to settle, and how long to wait at most.
    public static let settlePoll: Duration = .milliseconds(80)
    public static let settleLimit: Duration = .milliseconds(400)

    public static func stepPoints(regionHeight: Double) -> Double {
        (regionHeight * stepFraction).rounded(.down)
    }

    public static func shouldStop(noChangeInARow count: Int) -> Bool {
        count >= stillFramesToStop
    }

    public static func shouldStop(noMatchInARow count: Int) -> Bool {
        count >= lostFramesToStop
    }

    /// After a lost frame, scroll half as far so the next frames overlap.
    public static func stepAfterNoMatch(_ step: Double) -> Double {
        max(minimumStep, (step / 2).rounded(.down))
    }
}
