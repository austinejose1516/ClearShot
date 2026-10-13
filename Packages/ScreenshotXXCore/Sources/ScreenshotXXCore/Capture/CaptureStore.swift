import Foundation
import Observation

/// Recent captures, newest first. In memory only; files on disk are the real history.
@Observable
public final class CaptureStore {
    public private(set) var captures: [Capture] = []
    public let limit: Int

    public init(limit: Int = 20) {
        self.limit = limit
    }

    public func add(_ capture: Capture) {
        captures.insert(capture, at: 0)
        if captures.count > limit { captures.removeLast(captures.count - limit) }
    }

    public func remove(id: Capture.ID) {
        captures.removeAll { $0.id == id }
    }

    public func capture(id: Capture.ID) -> Capture? {
        captures.first { $0.id == id }
    }

    public func update(_ capture: Capture) {
        guard let index = captures.firstIndex(where: { $0.id == capture.id }) else { return }
        captures[index] = capture
    }
}
