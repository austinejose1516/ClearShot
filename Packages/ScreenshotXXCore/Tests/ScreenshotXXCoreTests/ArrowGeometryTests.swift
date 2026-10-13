import CoreGraphics
import Testing
@testable import ScreenshotXXCore

@Suite struct ArrowGeometryTests {
    @Test func headWingsSitBehindTheTipOnBothSides() {
        let head = ArrowGeometry.head(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0), length: 10, width: 8)
        #expect(abs(head.left.x - 90) < 0.001 && abs(head.left.y - 4) < 0.001)
        #expect(abs(head.right.x - 90) < 0.001 && abs(head.right.y + 4) < 0.001)
    }
}

@Suite struct ArrowHeadPlacementTests {
    @Test func headSizeFollowsTheLineWidthWithAMinimum() {
        #expect(ArrowGeometry.headLength(strokeWidth: 2) == 20)
        #expect(ArrowGeometry.headLength(strokeWidth: 4) == 20)
        #expect(ArrowGeometry.headLength(strokeWidth: 10) == 40)
    }

    @Test func aStraightArrowsHeadStartsOneHeadLengthBeforeTheEnd() {
        let line = Line(start: .zero, end: CGPoint(x: 100, y: 0), arrow: true)
        #expect(line.pointBefore(end: 20) == CGPoint(x: 80, y: 0))
        #expect(line.pointBefore(end: 500) == .zero)
    }

    @Test func aCurvedArrowsHeadBaseSitsOnTheCurve() {
        let curve = Curve.bent(from: .zero, to: CGPoint(x: 300, y: 0), arrow: true)
        let base = curve.pointBefore(end: 30)
        // On the curve…
        let onCurve = CurveGeometry.point(start: curve.start, control: curve.control, end: curve.end, t: base.t)
        #expect(hypot(onCurve.x - base.point.x, onCurve.y - base.point.y) < 0.001)
        // …about one head-length from the end.
        #expect(abs(hypot(curve.end.x - base.point.x, curve.end.y - base.point.y) - 30) < 1.5)
    }

    @Test func theTrimmedCurveEndsWhereTheHeadBegins() {
        let curve = Curve.bent(from: .zero, to: CGPoint(x: 300, y: 0), arrow: true)
        let base = curve.pointBefore(end: 30)
        let trimmed = curve.prefix(to: base.t)
        #expect(trimmed.start == curve.start)
        #expect(hypot(trimmed.end.x - base.point.x, trimmed.end.y - base.point.y) < 0.001)
        #expect(curve.prefix(to: 1) == curve)
    }
}
