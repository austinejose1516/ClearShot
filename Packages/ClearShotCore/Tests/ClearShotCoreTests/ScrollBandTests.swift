import CoreGraphics
import Testing
@testable import ClearShotCore

/// A window 64 pixels wide and 100 tall: a sidebar in columns 0..<16 that never moves, and content in 16..<64
/// scrolled down by `offset` rows (bands of six rows, each its own grey, like lines of text).
private func windowWithSidebar(offset: Int, caretAt caret: Int? = nil) -> CGImage {
    greyImage(width: 64, height: 100) { x, y in
        if x < 16 { return UInt8((y * 37 + 11) % 251) }
        if let caret, x == 40, (caret..<caret + 3).contains(y) { return 255 }
        return UInt8((((y + offset) / 6) * 53 + 7) % 251)
    }
}

@Suite struct ScrollBandTests {
    @Test func wholeRowsNeverMatchWhenASidebarStaysPut() {
        // Why a window with a sidebar never stitched: the sidebar half of each row does not move with the rest.
        var stitcher = ScrollStitcher(frameHeight: 100)
        _ = stitcher.add(FrameProfile.of(windowWithSidebar(offset: 0)))
        #expect(stitcher.add(FrameProfile.of(windowWithSidebar(offset: 30))) == .noMatch)
    }

    @Test func theBandIsThePartThatMoved() {
        #expect(ScrollBand.columns(between: windowWithSidebar(offset: 0), and: windowWithSidebar(offset: 30)) == 16..<64)
    }

    @Test func nothingMovedIsNoBand() {
        #expect(ScrollBand.columns(between: windowWithSidebar(offset: 0), and: windowWithSidebar(offset: 0)) == nil)
    }

    @Test func aBlinkingCaretIsNotScrolling() {
        #expect(ScrollBand.columns(between: windowWithSidebar(offset: 0), and: windowWithSidebar(offset: 0, caretAt: 50)) == nil)
    }

    @Test func rowsInsideTheBandMatchAfterAScroll() {
        let band = 16..<64
        var stitcher = ScrollStitcher(frameHeight: 100)
        #expect(stitcher.add(FrameProfile.of(windowWithSidebar(offset: 0), columns: band)) == .first)
        #expect(stitcher.add(FrameProfile.of(windowWithSidebar(offset: 30), columns: band)) == .appended(rows: 30))
    }

    @Test func thePageIsOnlyThePartThatScrolls() {
        let frames = [windowWithSidebar(offset: 0), windowWithSidebar(offset: 30)]
        let band = 16..<64
        var stitcher = ScrollStitcher(frameHeight: 100)
        for frame in frames { _ = stitcher.add(FrameProfile.of(frame, columns: band)) }
        let page = ScrollAssembler.assemble(frames: frames, slices: stitcher.slices, columns: band)
        #expect(page?.width == 48)
        #expect(page?.height == 130)
    }
}
