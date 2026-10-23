import CoreGraphics

/// Which uploads are selected in the Uploads window, and how clicks and arrow keys change that: like the
/// Finder. Items are known by their keys, in the order the grid shows them.
public struct UploadSelection: Equatable, Sendable {
    public struct Modifiers: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let command = Modifiers(rawValue: 1)
        public static let shift = Modifiers(rawValue: 2)
    }

    public enum Direction: Equatable, Sendable {
        case left, right, up, down
    }

    public private(set) var keys: Set<String> = []
    /// Where a ⇧-click's range starts, and where the arrow keys move from: the last plain or ⌘ click.
    private var anchor: String?

    public init() {}

    public var isEmpty: Bool { keys.isEmpty }

    /// The one selected key, when exactly one is selected (Copy Link and Open work on one).
    public var only: String? { keys.count == 1 ? keys.first : nil }

    /// A plain click selects that one; ⌘ adds or removes it; ⇧ selects from the last plain or ⌘ click to it.
    public mutating func click(_ key: String, in order: [String], modifiers: Modifiers) {
        if modifiers.contains(.shift) {
            guard let to = order.firstIndex(of: key) else { return }
            let from = anchor.flatMap { order.firstIndex(of: $0) } ?? 0
            keys = Set(order[min(from, to)...max(from, to)])
        } else if modifiers.contains(.command) {
            if keys.contains(key) { keys.remove(key) } else { keys.insert(key) }
            anchor = key
        } else {
            keys = [key]
            anchor = key
        }
    }

    public mutating func selectAll(_ order: [String]) {
        keys = Set(order)
    }

    public mutating func clear() {
        keys = []
        anchor = nil
    }

    /// After the filter changes: only what is still shown stays selected.
    public mutating func keep(in order: [String]) {
        keys.formIntersection(order)
        if let anchor, !order.contains(anchor) { self.anchor = nil }
    }

    /// An arrow key: one card sideways, one row up or down, from the last clicked card (or the first selected
    /// one); stops at the edges. With nothing selected it selects the first card.
    public mutating func move(_ direction: Direction, in order: [String], columns: Int) {
        guard let first = order.first else { return }
        let current = anchor.flatMap { keys.contains($0) ? $0 : nil } ?? order.first { keys.contains($0) }
        guard let current, let index = order.firstIndex(of: current) else {
            click(first, in: order, modifiers: [])
            return
        }
        let row = max(columns, 1)
        let step = switch direction {
        case .left: -1
        case .right: 1
        case .up: -row
        case .down: row
        }
        let target = index + step
        guard order.indices.contains(target) else { return }
        click(order[target], in: order, modifiers: [])
    }

    /// The cards a drag box touches, given where each card is.
    public static func keys(in box: CGRect, frames: [String: CGRect]) -> Set<String> {
        Set(frames.filter { $0.value.intersects(box) }.map(\.key))
    }

    /// A drag box: the cards it touches, on top of what was selected when the drag began (⌘ held) or nothing.
    public mutating func box(_ touched: Set<String>, onto base: Set<String>) {
        keys = base.union(touched)
    }

    /// How many columns an adaptive grid of `minimum`-wide items with `spacing` between them fits in `width`:
    /// SwiftUI's rule for `GridItem.adaptive`, so the arrow keys move by the rows the grid really has.
    public static func columns(forWidth width: Double, minimum: Double, spacing: Double) -> Int {
        max(1, Int((width + spacing) / (minimum + spacing)))
    }
}
