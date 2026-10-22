/// Builds one tall page out of frames taken while the page scrolls down. Works on frame profiles (see
/// `FrameProfile`): it finds how far the page moved between two frames by scoring every possible shift on how
/// much the overlapping rows differ, coarsely first and then exactly around the best, and takes the shift whose
/// rows differ least. The pixels are put together later by `ScrollAssembler`.
///
/// Frames are numbered in the order they are kept: a frame counts (and must be kept by the caller) only when
/// `add` answers `.first` or `.appended`; `.noChange` and `.noMatch` frames are dropped.
public struct ScrollStitcher {
    public enum Step: Equatable, Sendable {
        case first
        /// `rows` new rows were added to the bottom of the page.
        case appended(rows: Int)
        /// The same picture as the last kept frame: the page did not move (the end, or not yet).
        case noChange
        /// No overlap with the last kept frame found (scrolled too far, or something else changed).
        case noMatch
        /// The frame shows what is above the last kept one: the page was scrolled up. Nothing is added;
        /// scrolling back down past the last kept frame carries on.
        case scrolledUp
    }

    /// Rows of one kept frame that make up part of the page.
    public struct Slice: Equatable, Sendable {
        public let frame: Int
        public let rows: Range<Int>

        public init(frame: Int, rows: Range<Int>) {
            self.frame = frame
            self.rows = rows
        }
    }

    /// Two frames whose samples differ by at most this on average (0…255) show the same picture: the page did
    /// not move. A blinking caret or a ticking clock changes far too few samples to reach it.
    public static let sameThreshold = 1.5
    /// A shift counts when the overlapping rows differ by at most this on average (0…255). Rows that do not
    /// belong together differ by far more; a page sitting between two pixels, by far less.
    public static let matchThreshold = 16.0
    /// A row stayed put (part of a sticky header or footer) when it differs by at most this.
    static let stillRowThreshold = 6
    /// The coarse search tries every `coarseStep`th shift on every `coarseStep`th row, then looks at every
    /// shift within `coarseStep` of the `refined` best coarse shifts (the true shift's coarse neighbours can
    /// score worse than a wrong shift that happens to be uniformly close).
    static let coarseStep = 4
    static let refined = 4
    /// Shifts whose scores are this close are equally good: the expected one wins, or else the smallest.
    static let tieMargin = 0.5
    /// A shift is given up early once, after this many rows, its rows differ by more than the best shift so far
    /// plus twice the match threshold: rows that do not belong together are far worse from the start, while a
    /// changed line or two cannot push a good shift over it. Shifts are tried nearest the expected (or the
    /// last) shift first, so the best is usually found early and the rest are given up quickly.
    static let pruneAfterRows = 32

    public let frameHeight: Int
    /// Two frames must share at least this many rows to count as the same page scrolled. A tenth of the frame
    /// unless given: the planner scrolls by 60 %, which leaves 40 % in common.
    public let minimumOverlap: Int

    /// For the log: the best shift the last `add` found, even one too poor to count, and how much its rows
    /// differed (0…255). Nil when there was nothing to compare.
    public private(set) var closest: (shift: Int, distance: Double)?

    /// Rows at the top and bottom that do not scroll (a sticky header, a footer), found on the first scroll.
    public private(set) var header = 0
    public private(set) var footer = 0

    private var stickyKnown = false
    private var last: FrameProfile?
    private var lastShift: Int?
    private var lastFrame = 0
    private var keptFrames = 0
    private var appended: [Slice] = []
    private var bodyHeight = 0

    public init(frameHeight: Int, minimumOverlap: Int? = nil) {
        self.frameHeight = frameHeight
        self.minimumOverlap = minimumOverlap ?? max(10, frameHeight / 10)
    }

    public var totalHeight: Int {
        last == nil ? 0 : frameHeight + bodyHeight
    }

    /// How many frames tall the page is, rounded up.
    public var pages: Int {
        guard frameHeight > 0 else { return 1 }
        return max(1, Int((Double(totalHeight) / Double(frameHeight)).rounded(.up)))
    }

    /// The page, top to bottom: the header once (from the first frame), the first frame's body, every strip
    /// of new rows, and the footer once (from the last kept frame).
    public var slices: [Slice] {
        guard last != nil else { return [] }
        var result: [Slice] = []
        if header > 0 { result.append(Slice(frame: 0, rows: 0..<header)) }
        result.append(Slice(frame: 0, rows: header..<(frameHeight - footer)))
        result += appended
        if footer > 0 { result.append(Slice(frame: lastFrame, rows: (frameHeight - footer)..<frameHeight)) }
        return result
    }

    /// `expectedShift` is how far the caller scrolled, in rows, when it knows; among equally good shifts the
    /// nearest to it wins (a page of repeating rows fits several shifts).
    public mutating func add(_ frame: FrameProfile, expectedShift: Int? = nil) -> Step {
        guard frame.height == frameHeight, frameHeight > 0, frame.width > 0 else { return .noMatch }
        guard let previous = last else {
            last = frame
            lastFrame = 0
            keptFrames = 1
            return .first
        }
        guard previous.width == frame.width else { return .noMatch }
        if frame.distance(to: previous) <= Self.sameThreshold { return .noChange }
        // The sticky parts are measured on the first scroll, but only kept once that scroll really matched:
        // a stray frame must not fix them.
        let (top, bottom) = stickyKnown ? (header, footer) : stickyParts(previous, frame)
        let bandStart = top
        let bandEnd = frameHeight - bottom
        let bandHeight = bandEnd - bandStart
        // Almost every row stayed put: something changed in place (a GIF, a counter), the page did not move.
        guard bandHeight > minimumOverlap else { return .noChange }
        closest = nil
        let best = bestShift(from: previous, to: frame, band: bandStart..<bandEnd, expectedShift: expectedShift)
        closest = best
        guard best.distance <= Self.matchThreshold else { return .noMatch }
        // Lined up without moving: something on the page changed in place (a GIF, a counter), not a scroll.
        guard best.shift != 0 else { return .noChange }
        guard best.shift > 0 else { return .scrolledUp }
        if !stickyKnown {
            header = top
            footer = bottom
            stickyKnown = true
        }
        appended.append(Slice(frame: keptFrames, rows: (bandEnd - best.shift)..<bandEnd))
        bodyHeight += best.shift
        lastShift = best.shift
        last = frame
        lastFrame = keptFrames
        keptFrames += 1
        return .appended(rows: best.shift)
    }

    /// The shift (in rows) at which the new frame's band lines up best with the previous one. A shift of `s`
    /// means new row `i` shows what previous row `i + s` showed: positive is a scroll down, negative a scroll
    /// up, 0 no movement.
    private func bestShift(from previous: FrameProfile, to frame: FrameProfile, band: Range<Int>, expectedShift: Int?) -> (shift: Int, distance: Double) {
        let maxShift = band.count - minimumOverlap
        let width = frame.width
        let seed = expectedShift ?? lastShift ?? 0
        return previous.samples.withUnsafeBufferPointer { old in
            frame.samples.withUnsafeBufferPointer { new in
                /// The mean difference over the overlapping rows at `shift`, looking at every `rowStep`th row.
                /// Gives up, answering 255, once the shift is clearly worse than `limit`.
                func score(_ shift: Int, rowStep: Int, limit: Double) -> Double {
                    var total = 0, rows = 0
                    let giveUp = limit + 2 * Self.matchThreshold
                    // Only rows that both frames have at this shift.
                    let first = max(band.lowerBound, band.lowerBound - shift)
                    let last = min(band.upperBound, band.upperBound - shift)
                    for row in stride(from: first, to: last, by: rowStep) {
                        total &+= FrameProfile.rowDistance(new, row, old, row + shift, width: width)
                        rows += 1
                        if rows == Self.pruneAfterRows, Double(total) / Double(rows * width) > giveUp { return 255 }
                    }
                    return rows > 0 ? Double(total) / Double(rows * width) : 255
                }
                /// Every shift scored, nearest the seed first (so the best turns up early and the rest are cheap).
                func scores(of shifts: [Int], rowStep: Int) -> [(shift: Int, distance: Double)] {
                    var lowest = 255.0
                    return shifts.sorted { abs($0 - seed) < abs($1 - seed) }.map { shift in
                        let distance = score(shift, rowStep: rowStep, limit: lowest)
                        lowest = min(lowest, distance)
                        return (shift, distance)
                    }
                }
                /// The lowest score; near-ties go to the expected shift, else to a scroll down over no movement
                /// over a scroll up, the smallest first (a page of repeating rows fits several shifts).
                func pick(_ scored: [(shift: Int, distance: Double)]) -> (shift: Int, distance: Double) {
                    let lowest = scored.map(\.distance).min() ?? 255
                    let ties = scored.filter { $0.distance <= lowest + Self.tieMargin }
                    if let expectedShift, let nearest = ties.min(by: { abs($0.shift - expectedShift) < abs($1.shift - expectedShift) }) {
                        return nearest
                    }
                    func rank(_ shift: Int) -> (Int, Int) { (shift > 0 ? 0 : shift == 0 ? 1 : 2, abs(shift)) }
                    return ties.min { rank($0.shift) < rank($1.shift) } ?? (shift: 1, distance: 255)
                }
                let step = Self.coarseStep
                let reach = max(step, maxShift)
                let coarseShifts = Array(stride(from: step, through: reach, by: step)) + Array(stride(from: -step, through: -reach, by: -step))
                let coarse = scores(of: coarseShifts, rowStep: step)
                let around = coarse.sorted { $0.distance < $1.distance }.prefix(Self.refined)
                    .flatMap { max(-maxShift, $0.shift - step)...min(maxShift, $0.shift + step) }
                return pick(scores(of: Array(Set(around + [0])), rowStep: 1))   // 0: changed in place, not scrolled
            }
        }
    }

    /// Rows that stayed put at the top and at the bottom (never the whole frame: those frames differ).
    private func stickyParts(_ previous: FrameProfile, _ frame: FrameProfile) -> (top: Int, bottom: Int) {
        var top = 0
        while top < frameHeight, previous.rowDistance(top, to: frame, top) <= Self.stillRowThreshold { top += 1 }
        var bottom = 0
        while bottom < frameHeight - top,
              previous.rowDistance(frameHeight - 1 - bottom, to: frame, frameHeight - 1 - bottom) <= Self.stillRowThreshold {
            bottom += 1
        }
        return (top, bottom)
    }
}
