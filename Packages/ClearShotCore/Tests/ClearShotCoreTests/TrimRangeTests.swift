import Testing
@testable import ClearShotCore

@Suite struct TrimRangeTests {
    @Test func wholeCoversTheRecording() {
        let range = TrimRange.whole(total: 12.5)
        #expect(range.start == 0 && range.end == 12.5 && range.total == 12.5)
        #expect(range.duration == 12.5)
        #expect(range.isWhole)
        #expect(TrimRange(start: 1, end: 12.5, total: 12.5).isWhole == false)
    }

    @Test func handlesKeepAtLeastHalfASecondBetweenThem() {
        let range = TrimRange.whole(total: 10)
        #expect(range.movingStart(to: 9.8).start == 9.5)
        #expect(range.movingEnd(to: 0.2).end == 0.5)
        #expect(TrimRange.minimumLength == 0.5)
    }

    @Test func handlesStayInsideTheRecording() {
        let range = TrimRange.whole(total: 10)
        #expect(range.movingStart(to: -3).start == 0)
        #expect(range.movingEnd(to: 42).end == 10)
    }

    @Test func movingOneHandleLeavesTheOther() {
        let range = TrimRange(start: 2, end: 8, total: 10).movingStart(to: 3)
        #expect(range == TrimRange(start: 3, end: 8, total: 10))
        #expect(range.movingEnd(to: 6) == TrimRange(start: 3, end: 6, total: 10))
    }

    @Test func aRecordingShorterThanTheMinimumStaysWhole() {
        let range = TrimRange.whole(total: 0.3)
        #expect(range.movingStart(to: 0.2) == range)
        #expect(range.movingEnd(to: 0.1) == range)
    }

    @Test func initKeepsTheHandlesInsideTheRecording() {
        #expect(TrimRange(start: -1, end: 30, total: 10) == TrimRange(start: 0, end: 10, total: 10))
        #expect(TrimRange(start: 8, end: 2, total: 10).duration == 0)
    }
}
