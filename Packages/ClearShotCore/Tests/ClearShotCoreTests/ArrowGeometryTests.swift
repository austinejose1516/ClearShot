import CoreGraphics
import Testing
@testable import ClearShotCore

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
        let curve = Curve(start: .zero, end: CGPoint(x: 300, y: 0), bend: 60, arrow: true)
        let base = curve.pointBefore(end: 30)
        // On the curve…
        let onCurve = CurveGeometry.point(start: curve.start, control: curve.control, end: curve.end, t: base.t)
        #expect(hypot(onCurve.x - base.point.x, onCurve.y - base.point.y) < 0.001)
        // …about one head-length from the end.
        #expect(abs(hypot(curve.end.x - base.point.x, curve.end.y - base.point.y) - 30) < 1.5)
    }

    @Test func theTrimmedCurveEndsWhereTheHeadBegins() {
        let curve = Curve(start: .zero, end: CGPoint(x: 300, y: 0), bend: 60, arrow: true)
        let base = curve.pointBefore(end: 30)
        let trimmed = curve.segment(from: 0, to: base.t)
        #expect(trimmed.start == curve.start)
        #expect(hypot(trimmed.end.x - base.point.x, trimmed.end.y - base.point.y) < 0.001)
        let whole = curve.segment(from: 0, to: 1)
        #expect(whole.start == curve.start && whole.control == curve.control && whole.end == curve.end)
    }

    @Test func aTwoHeadedCurvesStartHeadBaseSitsOnTheCurveOneHeadLengthAfterTheStart() {
        let curve = Curve(start: .zero, end: CGPoint(x: 300, y: 0), bend: 60, arrow: true, bothEnds: true)
        let base = curve.pointAfter(start: 30)
        let onCurve = CurveGeometry.point(start: curve.start, control: curve.control, end: curve.end, t: base.t)
        #expect(hypot(onCurve.x - base.point.x, onCurve.y - base.point.y) < 0.001)
        #expect(abs(hypot(base.point.x - curve.start.x, base.point.y - curve.start.y) - 30) < 1.5)
        #expect(base.t > 0 && base.t < 0.5)
    }

    @Test func aCurveTrimmedAtBothEndsRunsBetweenTheTwoHeadBases() {
        let curve = Curve(start: .zero, end: CGPoint(x: 300, y: 0), bend: 60, arrow: true, bothEnds: true)
        let first = curve.pointAfter(start: 30), last = curve.pointBefore(end: 30)
        let piece = curve.segment(from: first.t, to: last.t)
        #expect(hypot(piece.start.x - first.point.x, piece.start.y - first.point.y) < 0.001)
        #expect(hypot(piece.end.x - last.point.x, piece.end.y - last.point.y) < 0.001)
        // The piece is the same curve: halfway along it is the original curve halfway between the two cuts.
        let halfway = CurveGeometry.point(start: piece.start, control: piece.control, end: piece.end, t: 0.5)
        let original = CurveGeometry.point(start: curve.start, control: curve.control, end: curve.end, t: (first.t + last.t) / 2)
        #expect(hypot(halfway.x - original.x, halfway.y - original.y) < 0.001)
    }
}
