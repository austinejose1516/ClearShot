import Testing
@testable import ClearShotCore

@Suite struct VideoTimeTests {
    @Test func clockShowsMinutesAndSeconds() {
        #expect(VideoTime.clock(0) == "0:00")
        #expect(VideoTime.clock(42.9) == "0:42")
        #expect(VideoTime.clock(102) == "1:42")
    }

    @Test func clockShowsHoursOnceThereAreAny() {
        #expect(VideoTime.clock(3903) == "1:05:03")
    }

    @Test func clockCanShowTenths() {
        #expect(VideoTime.clock(3.24, decimals: true) == "0:03.2")
        #expect(VideoTime.clock(65.06, decimals: true) == "1:05.1")
    }

    @Test func clockNeverGoesBelowZero() {
        #expect(VideoTime.clock(-2) == "0:00")
    }

    @Test func lengthUsesSecondsUnderAMinute() {
        #expect(VideoTime.length(8.94) == "8.9 s")
        #expect(VideoTime.length(102) == "1:42")
    }
}
