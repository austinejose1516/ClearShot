import Foundation

/// One box over a recording that is blurred or pixelated for the whole clip. `rect` is in video pixels,
/// origin top-left, like the editor's annotations.
public struct VideoBlur: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var rect: CGRect
    public var mode: BlurMode

    public init(id: UUID = UUID(), rect: CGRect, mode: BlurMode) {
        self.id = id
        self.rect = rect
        self.mode = mode
    }
}

/// The boxes of one recording, kept inside its frame. The newest is drawn on top and hit first.
public struct VideoBlurs: Equatable, Sendable {
    /// A box can never be thinner than this, so it stays visible and grabbable.
    public static let minimumSide: CGFloat = 8

    /// The video's size in pixels.
    public let frame: CGSize
    public private(set) var regions: [VideoBlur] = []

    public init(frame: CGSize) {
        self.frame = frame
    }

    public var isEmpty: Bool { regions.isEmpty }

    public subscript(id: VideoBlur.ID) -> VideoBlur? {
        regions.first { $0.id == id }
    }

    /// Adds the box clamped to the frame; nil (and nothing added) when what is left is too small.
    @discardableResult
    public mutating func add(_ rect: CGRect, mode: BlurMode) -> VideoBlur.ID? {
        let box = rect.standardized.intersection(bounds)
        guard !box.isNull, box.width >= Self.minimumSide, box.height >= Self.minimumSide else { return nil }
        let region = VideoBlur(rect: box, mode: mode)
        regions.append(region)
        return region.id
    }

    /// The topmost box under the point.
    public func region(at point: CGPoint) -> VideoBlur.ID? {
        regions.last { $0.rect.contains(point) }?.id
    }

    /// The corner of the box within `tolerance` of the point, if any.
    public func handle(of id: VideoBlur.ID, at point: CGPoint, tolerance: CGFloat) -> HandleKind? {
        guard let region = self[id] else { return nil }
        return region.rect.cornerHandles.first { hypot($0.point.x - point.x, $0.point.y - point.y) <= tolerance }?.kind
    }

    /// Moves the box to where the drag put it, slid back inside the frame; its size never changes.
    public mutating func move(_ id: VideoBlur.ID, to rect: CGRect) {
        let frame = frame
        update(id) { region in
            let size = region.rect.size
            region.rect.origin = CGPoint(x: min(max(0, rect.minX), frame.width - size.width),
                                         y: min(max(0, rect.minY), frame.height - size.height))
        }
    }

    /// Drags one corner; the opposite corner stays. The box stays in the frame and at least `minimumSide` wide
    /// and tall, growing away from the anchor when the pointer crosses it.
    public mutating func resize(_ id: VideoBlur.ID, dragging handle: HandleKind, to point: CGPoint) {
        let frame = frame, bounds = bounds
        update(id) { region in
            let anchor = region.rect.anchor(opposite: handle) ?? region.rect.origin
            let target = CGPoint(x: min(max(0, point.x), frame.width), y: min(max(0, point.y), frame.height))
            var dx = target.x - anchor.x, dy = target.y - anchor.y
            let xSign: CGFloat = handle == .topRight || handle == .bottomRight ? 1 : -1
            let ySign: CGFloat = handle == .bottomLeft || handle == .bottomRight ? 1 : -1
            if dx * xSign < Self.minimumSide { dx = Self.minimumSide * xSign }
            if dy * ySign < Self.minimumSide { dy = Self.minimumSide * ySign }
            let corner = CGPoint(x: anchor.x + dx, y: anchor.y + dy)
            region.rect = SelectionGeometry.normalizedRect(from: anchor, to: corner).intersection(bounds)
        }
    }

    public mutating func setMode(_ mode: BlurMode, of id: VideoBlur.ID) {
        update(id) { $0.mode = mode }
    }

    public mutating func remove(_ id: VideoBlur.ID) {
        regions.removeAll { $0.id == id }
    }

    private var bounds: CGRect { CGRect(origin: .zero, size: frame) }

    private mutating func update(_ id: VideoBlur.ID, _ change: (inout VideoBlur) -> Void) {
        guard let index = regions.firstIndex(where: { $0.id == id }) else { return }
        change(&regions[index])
    }
}
