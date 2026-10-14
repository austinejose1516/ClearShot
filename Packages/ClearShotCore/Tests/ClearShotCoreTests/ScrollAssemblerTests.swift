import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct ScrollAssemblerTests {
    @Test func slicesAreStackedTopToBottom() throws {
        let frames = [rowImage([1, 2, 3, 4]), rowImage([3, 4, 5, 6])]
        let slices = [ScrollStitcher.Slice(frame: 0, rows: 0..<4), ScrollStitcher.Slice(frame: 1, rows: 2..<4)]
        let image = try #require(ScrollAssembler.assemble(frames: frames, slices: slices))
        #expect(image.width == 8 && image.height == 6)
        #expect(leftColumn(of: image) == [1, 2, 3, 4, 5, 6])
    }

    @Test func nothingToStackGivesNil() {
        #expect(ScrollAssembler.assemble(frames: [], slices: []) == nil)
        #expect(ScrollAssembler.assemble(frames: [rowImage([1])], slices: []) == nil)
    }

    @Test func aTooTallResultIsCutAtTheLimit() throws {
        let frame = rowImage(Array(repeating: 9, count: 100))
        let slices = Array(repeating: ScrollStitcher.Slice(frame: 0, rows: 0..<100), count: 400)   // 40 000 rows
        let image = try #require(ScrollAssembler.assemble(frames: [frame], slices: slices))
        #expect(image.height == ScrollAssembler.maxHeight)
    }
}
