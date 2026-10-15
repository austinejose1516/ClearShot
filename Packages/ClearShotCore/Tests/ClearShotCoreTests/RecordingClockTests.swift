import Foundation
import Testing
@testable import ClearShotCore

@Suite struct RecordingClockTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    @Test func countsFromTheStart() {
        let clock = RecordingClock(startedAt: start)
        #expect(clock.elapsed(at: start) == 0)
        #expect(clock.elapsed(at: start + 12) == 12)
        #expect(clock.isPaused == false)
    }

    @Test func pausingStopsTheCount() {
        var clock = RecordingClock(startedAt: start)
        clock.pause(at: start + 5)
        #expect(clock.isPaused)
        #expect(clock.elapsed(at: start + 5) == 5)
        #expect(clock.elapsed(at: start + 60) == 5)
    }

    @Test func resumingLeavesThePausedPartOut() {
        var clock = RecordingClock(startedAt: start)
        clock.pause(at: start + 5)
        clock.resume(at: start + 20)
        #expect(clock.isPaused == false)
        #expect(clock.elapsed(at: start + 20) == 5)
        #expect(clock.elapsed(at: start + 23) == 8)
    }

    @Test func severalPausesAddUp() {
        var clock = RecordingClock(startedAt: start)
        clock.pause(at: start + 2)
        clock.resume(at: start + 10)
        clock.pause(at: start + 13)
        clock.resume(at: start + 30)
        #expect(clock.elapsed(at: start + 31) == 6)
    }

    @Test func pausingTwiceOrResumingWhileRunningChangesNothing() {
        var clock = RecordingClock(startedAt: start)
        clock.resume(at: start + 3)
        #expect(clock.elapsed(at: start + 4) == 4)
        clock.pause(at: start + 5)
        clock.pause(at: start + 9)
        #expect(clock.elapsed(at: start + 9) == 5)
    }
}
