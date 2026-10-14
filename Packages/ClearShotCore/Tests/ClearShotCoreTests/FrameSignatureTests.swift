import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct FrameSignatureTests {
    @Test func oneHashPerRowAndTheSameImageGivesTheSameHashes() {
        let rows = FrameSignature.rows(of: rowImage([10, 20, 30]))
        #expect(rows.count == 3)
        #expect(rows[0] != rows[1] && rows[1] != rows[2])
        #expect(rows == FrameSignature.rows(of: rowImage([10, 20, 30])))
    }

    @Test func aChangedRowChangesOnlyItsOwnHash() {
        let before = FrameSignature.rows(of: rowImage([10, 20, 30]))
        let after = FrameSignature.rows(of: rowImage([10, 99, 30]))
        #expect(before[0] == after[0] && before[2] == after[2])
        #expect(before[1] != after[1])
    }

    @Test func equalRowsHashTheSameWhereverTheyAre() {
        let rows = FrameSignature.rows(of: rowImage([7, 8, 7, 8]))
        #expect(rows[0] == rows[2] && rows[1] == rows[3] && rows[0] != rows[1])
    }

    @Test func theRightEdgeCanBeLeftOutForTheScrollbar() {
        // Rows differ only in the rightmost 4 pixels (a scrollbar thumb that moved).
        let plain = greyImage(width: 32, height: 2) { _, _ in 50 }
        let withThumb = greyImage(width: 32, height: 2) { x, y in x >= 28 && y == 0 ? 200 : 50 }
        #expect(FrameSignature.rows(of: plain) != FrameSignature.rows(of: withThumb))
        #expect(FrameSignature.rows(of: plain, ignoringRightPixels: 4) == FrameSignature.rows(of: withThumb, ignoringRightPixels: 4))
    }
}
