import Testing
@testable import ClearShotCore

/// SplitMix64: the same numbers every run.
private struct Random {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func next(below bound: Int) -> Int { Int(next() % UInt64(bound)) }
}

/// A made-up page that looks like a screen: blocks of one grey, 4 to 24 rows tall (lines of text, boxes),
/// each block different from the last, with a sticky header and footer that never move.
private struct Page {
    static let width = 32
    let rows: [[UInt8]]
    let frameHeight: Int
    let header: Int
    let footer: Int

    init(length: Int = 400, frameHeight: Int = 100, header: Int = 10, footer: Int = 10, seed: UInt64 = 1) {
        var random = Random(seed: seed)
        var rows: [[UInt8]] = []
        while rows.count < length {
            let row = (0..<Self.width).map { _ in UInt8(random.next(below: 256)) }
            rows += Array(repeating: row, count: 4 + random.next(below: 21))
        }
        self.rows = Array(rows.prefix(length))
        self.frameHeight = frameHeight
        self.header = header
        self.footer = footer
    }

    var bandHeight: Int { frameHeight - header - footer }
    var maxOffset: Int { rows.count - bandHeight }
    private var headerRows: [[UInt8]] { (0..<header).map { Array(repeating: UInt8(1 + $0), count: Self.width) } }
    private var footerRows: [[UInt8]] { (0..<footer).map { Array(repeating: UInt8(100 + $0), count: Self.width) } }

    /// What the screen shows with the page scrolled down by `offset` rows.
    func frame(offset: Int) -> FrameProfile {
        let offset = min(offset, maxOffset)
        return profile(headerRows + Array(rows[offset..<(offset + bandHeight)]) + footerRows)
    }

    /// The screen scrolled by `offset` and a half: every row is the average of two neighbouring rows, as when
    /// the page sits between two pixels; `jitter` adds a little antialiasing noise to every sample.
    func halfPixelFrame(offset: Int, jitter: Int = 4, seed: UInt64 = 7) -> FrameProfile {
        var random = Random(seed: seed)
        let body = (0..<bandHeight).map { index -> [UInt8] in
            zip(rows[offset + index], rows[offset + index + 1]).map { a, b in
                let blended = (Int(a) + Int(b)) / 2 + random.next(below: 2 * jitter + 1) - jitter
                return UInt8(max(0, min(255, blended)))
            }
        }
        return profile(headerRows + body + footerRows)
    }

    /// The whole page as it should come out: header once, every row, footer once.
    var expected: [[UInt8]] { headerRows + rows + footerRows }

    func profile(_ rows: [[UInt8]]) -> FrameProfile {
        FrameProfile(height: rows.count, width: Self.width, samples: rows.flatMap { $0 })
    }
}

/// Puts the stitcher's slices back together from the frames' rows.
private func flatten(_ stitcher: ScrollStitcher, frames: [FrameProfile]) -> [[UInt8]] {
    stitcher.slices.flatMap { slice in slice.rows.map { frames[slice.frame].row($0) } }
}

private func randomFrame(height: Int, seed: UInt64) -> FrameProfile {
    var random = Random(seed: seed)
    return FrameProfile(height: height, width: Page.width, samples: (0..<(height * Page.width)).map { _ in UInt8(random.next(below: 256)) })
}

@Suite struct ScrollStitcherTests {
    @Test func scrollingDownAppendsTheNewRowsAndKeepsTheStickyParts() {
        let page = Page()
        var stitcher = ScrollStitcher(frameHeight: page.frameHeight)
        let frames = [page.frame(offset: 0), page.frame(offset: 60), page.frame(offset: 120)]
        #expect(stitcher.add(frames[0]) == .first)
        #expect(stitcher.add(frames[1]) == .appended(rows: 60))
        #expect(stitcher.header == 10 && stitcher.footer == 10)
        #expect(stitcher.add(frames[2]) == .appended(rows: 60))
        #expect(stitcher.totalHeight == 10 + 80 + 60 + 60 + 10)
        #expect(stitcher.pages == 3)
        #expect(flatten(stitcher, frames: frames) == Array(page.expected.prefix(10 + 200)) + page.expected.suffix(10))
    }

    @Test func theWholePageComesOutOnceWhenScrolledToTheEnd() {
        let page = Page()
        var stitcher = ScrollStitcher(frameHeight: page.frameHeight)
        var frames: [FrameProfile] = []
        for offset in stride(from: 0, through: page.maxOffset + 60, by: 60) {
            frames.append(page.frame(offset: offset))
            _ = stitcher.add(frames.last!, expectedShift: 60)
        }
        #expect(flatten(stitcher, frames: frames) == page.expected)
    }

    @Test func aScrollThatLandsBetweenTwoPixelsStillMatches() {
        // Why every capture kept one picture: a trackpad scroll leaves the page between two pixels, so every
        // row is redrawn a little differently and no row is exactly the same as before.
        let page = Page(length: 800, frameHeight: 200, header: 0, footer: 0)
        var stitcher = ScrollStitcher(frameHeight: 200)
        _ = stitcher.add(page.frame(offset: 0))
        let step = stitcher.add(page.halfPixelFrame(offset: 110))
        #expect(step == .appended(rows: 110) || step == .appended(rows: 111), "\(step)")
        // And the next frame, between pixels again, matches the one before it.
        let next = stitcher.add(page.halfPixelFrame(offset: 230, seed: 9))
        #expect(next == .appended(rows: 120) || next == .appended(rows: 119) || next == .appended(rows: 121), "\(next)")
    }

    @Test func theSameFrameAgainIsNoChange() {
        let page = Page()
        var stitcher = ScrollStitcher(frameHeight: page.frameHeight)
        _ = stitcher.add(page.frame(offset: 0))
        #expect(stitcher.add(page.frame(offset: 0)) == .noChange)
        _ = stitcher.add(page.frame(offset: 60))
        #expect(stitcher.add(page.frame(offset: 60)) == .noChange)
        #expect(stitcher.totalHeight == 10 + 80 + 60 + 10)
    }

    @Test func aBlinkingCaretIsStillNoChange() {
        let page = Page(length: 400, frameHeight: 100, header: 0, footer: 0)
        var stitcher = ScrollStitcher(frameHeight: 100)
        _ = stitcher.add(page.frame(offset: 0))
        var rows = (0..<100).map { page.frame(offset: 0).row($0) }
        for row in 40..<43 { rows[row][5] = 255; rows[row][6] = 255 }   // a caret, two samples wide, three rows tall
        #expect(stitcher.add(page.profile(rows)) == .noChange)
    }

    @Test func aFrameFromSomewhereElseIsNoMatchAndChangesNothing() {
        let page = Page()
        var stitcher = ScrollStitcher(frameHeight: page.frameHeight)
        _ = stitcher.add(page.frame(offset: 0))
        #expect(stitcher.add(randomFrame(height: page.frameHeight, seed: 99)) == .noMatch)
        #expect(stitcher.totalHeight == page.frameHeight)
        // The next real frame still matches the last good one.
        #expect(stitcher.add(page.frame(offset: 60)) == .appended(rows: 60))
    }

    @Test func aNearMissSaysHowCloseItCame() {
        let page = Page()
        var stitcher = ScrollStitcher(frameHeight: page.frameHeight)
        _ = stitcher.add(page.frame(offset: 0))
        // Scrolled by 30 rows, but 20 of the 50 overlapping body rows came out as something else entirely.
        var rows = (0..<page.frameHeight).map { page.frame(offset: 30).row($0) }
        let noise = randomFrame(height: 20, seed: 5)
        for (index, row) in (10..<30).enumerated() { rows[row] = noise.row(index) }
        #expect(stitcher.add(page.profile(rows)) == .noMatch)
        #expect(stitcher.closest?.shift == 30)
        #expect(stitcher.closest.map { $0.distance > ScrollStitcher.matchThreshold && $0.distance < 60 } == true)
    }

    @Test func aShorterScrollAtTheEndOfThePageIsAppendedAsIs() {
        let page = Page()
        var stitcher = ScrollStitcher(frameHeight: page.frameHeight)
        _ = stitcher.add(page.frame(offset: 300))
        #expect(stitcher.add(page.frame(offset: 360), expectedShift: 60) == .appended(rows: 20))   // the page ends at 320
    }

    @Test func aFewChangedRowsInTheOverlapStillMatch() {
        let page = Page(length: 600, frameHeight: 200, header: 0, footer: 0)
        var stitcher = ScrollStitcher(frameHeight: 200)
        _ = stitcher.add(page.frame(offset: 0))
        var rows = (0..<200).map { page.frame(offset: 100).row($0) }
        rows[10] = Array(repeating: 1, count: Page.width)   // a clock that ticked, say
        rows[20] = Array(repeating: 2, count: Page.width)
        #expect(stitcher.add(page.profile(rows)) == .appended(rows: 100))
    }

    @Test func aRepeatingPagePrefersTheExpectedShift() {
        // Every 48 rows look the same, so a scroll of 120 rows also fits shifts of 24, 72 and 168.
        let light = Array(repeating: UInt8(200), count: Page.width), dark = Array(repeating: UInt8(40), count: Page.width)
        let repeating = (0..<2000).map { $0 % 48 < 16 ? light : dark }
        let page = Page(length: 1, frameHeight: 200, header: 0, footer: 0)
        var without = ScrollStitcher(frameHeight: 200)
        _ = without.add(page.profile(Array(repeating[0..<200])))
        #expect(without.add(page.profile(Array(repeating[120..<320]))) == .appended(rows: 24))
        var with = ScrollStitcher(frameHeight: 200)
        _ = with.add(page.profile(Array(repeating[0..<200])))
        #expect(with.add(page.profile(Array(repeating[120..<320])), expectedShift: 120) == .appended(rows: 120))
    }

    @Test func theWrongNumberOfRowsIsNoMatch() {
        var stitcher = ScrollStitcher(frameHeight: 100)
        #expect(stitcher.add(randomFrame(height: 3, seed: 1)) == .noMatch)
        _ = stitcher.add(randomFrame(height: 100, seed: 2))
        #expect(stitcher.add(randomFrame(height: 3, seed: 3)) == .noMatch)
    }

    @Test func aTallStickyHeaderIsKeptOnceToo() {
        let page = Page(length: 400, frameHeight: 100, header: 50, footer: 0)
        var stitcher = ScrollStitcher(frameHeight: 100)
        let frames = [page.frame(offset: 0), page.frame(offset: 30)]
        _ = stitcher.add(frames[0])
        #expect(stitcher.add(frames[1]) == .appended(rows: 30))
        #expect(stitcher.header == 50 && stitcher.footer == 0)
        #expect(flatten(stitcher, frames: frames) == Array(page.expected.prefix(50 + 80)))
    }
}
