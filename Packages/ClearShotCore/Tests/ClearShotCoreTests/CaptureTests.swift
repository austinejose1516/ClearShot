import Testing
@testable import ClearShotCore

@Suite struct CaptureTests {
    @Test func aScrollingShotKnowsHowManyPagesItIs() {
        let scrolling = Capture(kind: .scrolling, image: blankImage(), pageCount: 3)
        #expect(scrolling.kind == .scrolling)
        #expect(scrolling.pageCount == 3)
        #expect(Capture(kind: .area, image: blankImage()).pageCount == 1)
    }

    @Test func scrollingIsOneOfTheKinds() {
        #expect(CaptureKind.allCases.contains(.scrolling))
        #expect(CaptureKind.scrolling.rawValue == "scrolling")
    }
}
