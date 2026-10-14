import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct TrimBarGeometryTests {
    @Test func xAndSecondsAreLinearAcrossTheBar() {
        #expect(TrimBarGeometry.x(forSeconds: 5, width: 400, total: 20) == 100)
        #expect(TrimBarGeometry.seconds(atX: 100, width: 400, total: 20) == 5)
        #expect(TrimBarGeometry.x(forSeconds: 0, width: 400, total: 20) == 0)
        #expect(TrimBarGeometry.x(forSeconds: 20, width: 400, total: 20) == 400)
    }

    @Test func pointsOutsideTheBarClampToItsEnds() {
        #expect(TrimBarGeometry.seconds(atX: -40, width: 400, total: 20) == 0)
        #expect(TrimBarGeometry.seconds(atX: 900, width: 400, total: 20) == 20)
    }

    @Test func anEmptyRecordingOrBarGivesZero() {
        #expect(TrimBarGeometry.seconds(atX: 10, width: 0, total: 20) == 0)
        #expect(TrimBarGeometry.x(forSeconds: 10, width: 400, total: 0) == 0)
    }

    @Test func thumbnailTimesAreTheMiddlesOfEqualSlices() {
        #expect(TrimBarGeometry.thumbnailTimes(count: 4, total: 8) == [1, 3, 5, 7])
        #expect(TrimBarGeometry.thumbnailTimes(count: 0, total: 8) == [])
        #expect(TrimBarGeometry.thumbnailTimes(count: 3, total: 0) == [0, 0, 0])
    }
}
