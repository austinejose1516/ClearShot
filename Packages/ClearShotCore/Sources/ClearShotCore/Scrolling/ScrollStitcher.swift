/// Builds one tall page out of frames taken while the page scrolls down. Works on row hashes (see
/// `FrameSignature`), so it is pure and fast. The pixels are put together later by `ScrollAssembler`.
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

    public let frameHeight: Int
    /// Two frames must share at least this many rows to count as the same page scrolled. A tenth of the frame
    /// unless given: the planner scrolls by 60 %, which leaves 40 % in common.
    public let minimumOverlap: Int
    /// The share of overlapping rows allowed to differ (a caret blinking, a clock ticking).
    public let tolerance: Double

    /// Rows at the top and bottom that do not scroll (a sticky header, a footer), found on the first scroll.
    public private(set) var header = 0
    public private(set) var footer = 0

    private var stickyKnown = false
    private var last: [UInt64]?
    private var lastFrame = 0
    private var keptFrames = 0
    private var appended: [Slice] = []
    private var bodyHeight = 0

    public init(frameHeight: Int, minimumOverlap: Int? = nil, tolerance: Double = 0.03) {
        self.frameHeight = frameHeight
        self.minimumOverlap = minimumOverlap ?? max(10, frameHeight / 10)
        self.tolerance = tolerance
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

    /// `expectedShift` is how far the caller scrolled, in rows, when it knows; among equally good matches the
    /// nearest to it wins (a page of repeating rows fits several shifts).
    public mutating func add(_ rows: [UInt64], expectedShift: Int? = nil) -> Step {
        guard rows.count == frameHeight, frameHeight > 0 else { return .noMatch }
        guard let previous = last else {
            last = rows
            lastFrame = 0
            keptFrames = 1
            return .first
        }
        if rows == previous { return .noChange }
        // The sticky parts are measured on the first scroll, but only kept once that scroll really matched:
        // a stray frame must not fix them.
        let (top, bottom) = stickyKnown ? (header, footer) : stickyParts(previous, rows)
        let bandStart = top
        let bandEnd = frameHeight - bottom
        let bandHeight = bandEnd - bandStart
        guard bandHeight > minimumOverlap else { return .noMatch }
        let previousBand = Array(previous[bandStart..<bandEnd])
        let newBand = Array(rows[bandStart..<bandEnd])

        var best: (shift: Int, score: Double)?
        for shift in 1...(bandHeight - minimumOverlap) {
            let overlap = bandHeight - shift
            var equal = 0
            for index in 0..<overlap where previousBand[shift + index] == newBand[index] { equal += 1 }
            let score = Double(equal) / Double(overlap)
            guard score >= 1 - tolerance else { continue }
            guard let current = best else {
                best = (shift, score)
                continue
            }
            if let expectedShift {
                if abs(shift - expectedShift) < abs(current.shift - expectedShift) { best = (shift, score) }
            } else if score > current.score {   // a tie keeps the smaller shift, found first
                best = (shift, score)
            }
        }
        guard let best else { return .noMatch }
        if !stickyKnown {
            header = top
            footer = bottom
            stickyKnown = true
        }
        appended.append(Slice(frame: keptFrames, rows: (bandEnd - best.shift)..<bandEnd))
        bodyHeight += best.shift
        last = rows
        lastFrame = keptFrames
        keptFrames += 1
        return .appended(rows: best.shift)
    }

    /// Rows that stayed put at the top and at the bottom (never the whole frame: those frames differ).
    private func stickyParts(_ previous: [UInt64], _ rows: [UInt64]) -> (top: Int, bottom: Int) {
        var top = 0
        while top < frameHeight, previous[top] == rows[top] { top += 1 }
        var bottom = 0
        while bottom < frameHeight - top, previous[frameHeight - 1 - bottom] == rows[frameHeight - 1 - bottom] { bottom += 1 }
        return (top, bottom)
    }
}
