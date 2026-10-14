import CoreGraphics

/// Scrolls whatever is under a point, the way a trackpad does: pixel deltas with a begin, change and end
/// phase, so apps scroll at once instead of animating. Needs the Accessibility permission to reach other apps.
enum ScrollInjector {
    /// Scrolls down by `points` at `point` (Quartz coordinates, top-left origin).
    static func scrollDown(by points: Int, at point: CGPoint) {
        for (phase, delta) in [(CGScrollPhase.began, 0), (.changed, -points), (.ended, 0)] {
            guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                                      wheel1: Int32(delta), wheel2: 0, wheel3: 0) else { continue }
            event.location = point
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            event.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(phase.rawValue))
            event.post(tap: .cghidEventTap)
        }
    }
}
