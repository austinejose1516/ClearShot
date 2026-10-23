import CoreGraphics
import Observation

/// The box being dragged on one screen, in that screen's view points (top-left origin). Begun, moved and
/// ended by whatever tracks the mouse; watched by the view that draws the box.
@Observable
public final class AreaDrag {
    public private(set) var start: CGPoint?
    public private(set) var current: CGPoint?

    public init() {}

    public var isActive: Bool { start != nil }

    /// The box so far.
    public var rect: CGRect? {
        guard let start, let current else { return nil }
        return SelectionGeometry.normalizedRect(from: start, to: current)
    }

    public func begin(at point: CGPoint) {
        start = point
        current = point
    }

    public func move(to point: CGPoint) {
        guard start != nil else { return }
        current = point
    }

    /// Ends the drag: the box when it is big enough to be a selection, nil for a click or when no drag was on.
    public func end(at point: CGPoint) -> CGRect? {
        guard let start else { return nil }
        let rect = SelectionGeometry.normalizedRect(from: start, to: point)
        self.start = nil
        current = nil
        return SelectionGeometry.isUsable(rect) ? rect : nil
    }
}
