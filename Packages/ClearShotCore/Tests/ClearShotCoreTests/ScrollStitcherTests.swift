import Testing
@testable import ClearShotCore

/// Frames of a made-up page: unique row hashes, with a sticky header and footer that never move.
private struct Page {
    let rows: [UInt64]
    let frameHeight: Int
    let header: Int
    let footer: Int

    init(length: Int = 400, frameHeight: Int = 100, header: Int = 10, footer: Int = 10) {
        rows = (0..<length).map { UInt64(1000 + $0) }
        self.frameHeight = frameHeight
        self.header = header
        self.footer = footer
    }

    var bandHeight: Int { frameHeight - header - footer }
    var maxOffset: Int { rows.count - bandHeight }

    /// What the screen shows with the page scrolled down by `offset` rows.
    func frame(offset: Int) -> [UInt64] {
        let offset = min(offset, maxOffset)
        return (0..<header).map { UInt64(1 + $0) } + Array(rows[offset..<(offset + bandHeight)]) + (0..<footer).map { UInt64(100 + $0) }
    }

    /// The whole page as it should come out: header once, every row, footer once.
    var expected: [UInt64] {
        (0..<header).map { UInt64(1 + $0) } + rows + (0..<footer).map { UInt64(100 + $0) }
    }
}

/// Puts the stitcher's slices back together from the frames' rows.
private func flatten(_ stitcher: ScrollStitcher, frames: [[UInt64]]) -> [UInt64] {
    stitcher.slices.flatMap { Array(frames[$0.frame][$0.rows]) }
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
        var frames: [[UInt64]] = []
        for offset in stride(from: 0, through: page.maxOffset + 60, by: 60) {
            frames.append(page.frame(offset: offset))
            _ = stitcher.add(frames.last!, expectedShift: 60)
        }
        #expect(flatten(stitcher, frames: frames) == page.expected)
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

    @Test func aFrameFromSomewhereElseIsNoMatchAndChangesNothing() {
        let page = Page()
        var stitcher = ScrollStitcher(frameHeight: page.frameHeight)
        _ = stitcher.add(page.frame(offset: 0))
        let elsewhere = (0..<page.frameHeight).map { UInt64(50_000 + $0) }
        #expect(stitcher.add(elsewhere) == .noMatch)
        #expect(stitcher.totalHeight == page.frameHeight)
        // The next real frame still matches the last good one.
        #expect(stitcher.add(page.frame(offset: 60)) == .appended(rows: 60))
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
        var next = page.frame(offset: 100)
        next[10] = 1   // a blinking caret, say
        next[20] = 2
        #expect(stitcher.add(next) == .appended(rows: 100))
    }

    @Test func aRepeatingPagePrefersTheExpectedShift() {
        // Every 50 rows look the same, so a scroll of 125 rows also fits shifts of 25, 75 and 175.
        let repeating = (0..<2000).map { UInt64(1 + $0 % 50) }
        var without = ScrollStitcher(frameHeight: 200)
        _ = without.add(Array(repeating[0..<200]))
        #expect(without.add(Array(repeating[125..<325])) == .appended(rows: 25))
        var with = ScrollStitcher(frameHeight: 200)
        _ = with.add(Array(repeating[0..<200]))
        #expect(with.add(Array(repeating[125..<325]), expectedShift: 125) == .appended(rows: 125))
    }

    @Test func theWrongNumberOfRowsIsNoMatch() {
        var stitcher = ScrollStitcher(frameHeight: 100)
        #expect(stitcher.add([1, 2, 3]) == .noMatch)
        _ = stitcher.add((0..<100).map { UInt64($0) })
        #expect(stitcher.add([1, 2, 3]) == .noMatch)
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
