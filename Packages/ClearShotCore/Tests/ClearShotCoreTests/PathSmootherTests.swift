import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct PathSmootherTests {
    @Test func fewerThanTwoPointsGiveNothing() {
        #expect(PathSmoother.segments(through: [CGPoint(x: 1, y: 1)]) == nil)
    }

    @Test func twoPointsGiveOneStraightSegment() {
        let result = PathSmoother.segments(through: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)])!
        #expect(result.start == CGPoint(x: 0, y: 0))
        #expect(result.segments.count == 1)
        #expect(result.segments[0].end == CGPoint(x: 10, y: 0))
        #expect(result.segments[0].control1.y == 0 && result.segments[0].control2.y == 0)
    }

    @Test func segmentsEndAtEveryInputPoint() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 5), CGPoint(x: 20, y: -5), CGPoint(x: 30, y: 0)]
        let result = PathSmoother.segments(through: points)!
        #expect(result.segments.map(\.end) == Array(points.dropFirst()))
    }
}
