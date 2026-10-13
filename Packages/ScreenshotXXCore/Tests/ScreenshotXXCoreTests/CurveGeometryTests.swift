import CoreGraphics
import Testing
@testable import ScreenshotXXCore

@Suite struct CurveGeometryTests {
    private let start = CGPoint(x: 0, y: 0), control = CGPoint(x: 50, y: 100), end = CGPoint(x: 100, y: 0)

    @Test func midpointOfAQuadraticCurve() {
        #expect(CurveGeometry.point(start: start, control: control, end: end, t: 0.5) == CGPoint(x: 50, y: 50))
    }

    @Test func samplesRunFromStartToEnd() {
        let samples = CurveGeometry.samples(start: start, control: control, end: end, count: 4)
        #expect(samples.count == 5)
        #expect(samples.first == start && samples.last == end)
    }

    @Test func curveAnnotationHitsNearTheCurveOnly() {
        var curve = Annotation(kind: .curve(Curve(start: start, control: control, end: end, arrow: true)), style: .init(strokeWidth: 4))
        #expect(curve.hitTest(CGPoint(x: 50, y: 50), tolerance: 2) == true)
        #expect(curve.hitTest(CGPoint(x: 50, y: 90), tolerance: 2) == false)
        #expect(curve.bounds == CGRect(x: 0, y: 0, width: 100, height: 50))
        curve.move(by: CGVector(dx: 10, dy: 0))
        #expect(curve.hitTest(CGPoint(x: 60, y: 50), tolerance: 2) == true)
    }
}
