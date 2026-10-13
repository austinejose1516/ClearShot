/// Snapshot-based undo: every committed state is a full copy. Simple, and cheap at our sizes.
public struct UndoStack<State: Equatable> {
    private var past: [State] = []
    private var future: [State] = []
    public private(set) var current: State
    public let limit: Int

    public init(initial: State, limit: Int = 100) {
        current = initial
        self.limit = limit
    }

    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }

    public mutating func push(_ state: State) {
        guard state != current else { return }
        past.append(current)
        if past.count > limit { past.removeFirst(past.count - limit) }
        current = state
        future.removeAll()
    }

    @discardableResult
    public mutating func undo() -> State? {
        guard let previous = past.popLast() else { return nil }
        future.append(current)
        current = previous
        return previous
    }

    @discardableResult
    public mutating func redo() -> State? {
        guard let next = future.popLast() else { return nil }
        past.append(current)
        current = next
        return next
    }
}
