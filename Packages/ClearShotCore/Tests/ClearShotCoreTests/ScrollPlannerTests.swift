import Testing
@testable import ClearShotCore

@Suite struct ScrollPlannerTests {
    @Test func eachStepIsMostOfTheRegionSoFramesOverlap() {
        #expect(ScrollPlanner.stepPoints(regionHeight: 500) == 300)
        #expect(ScrollPlanner.stepPoints(regionHeight: 33) == 19)
    }

    @Test func stopsAfterTwoStillFramesOrThreeLostOnes() {
        #expect(ScrollPlanner.shouldStop(noChangeInARow: 1) == false)
        #expect(ScrollPlanner.shouldStop(noChangeInARow: 2))
        #expect(ScrollPlanner.shouldStop(noMatchInARow: 2) == false)
        #expect(ScrollPlanner.shouldStop(noMatchInARow: 3))
    }

    @Test func aLostFrameHalvesTheStepButNotBelowTwentyPoints() {
        #expect(ScrollPlanner.stepAfterNoMatch(300) == 150)
        #expect(ScrollPlanner.stepAfterNoMatch(30) == 20)
    }
}
