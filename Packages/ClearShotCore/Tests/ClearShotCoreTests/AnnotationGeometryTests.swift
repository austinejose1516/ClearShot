import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct AnnotationGeometryTests {
    @Test func distanceToSegmentHandlesTheMiddleAndBeyondTheEnds() {
        let a = CGPoint(x: 0, y: 0), b = CGPoint(x: 10, y: 0)
        #expect(AnnotationGeometry.distance(from: CGPoint(x: 5, y: 3), toSegment: a, b) == 3)
        #expect(AnnotationGeometry.distance(from: CGPoint(x: 20, y: 0), toSegment: a, b) == 10)
    }

    @Test func lineHitsWithinStrokeAndTolerance() {
        let line = Annotation(kind: .line(Line(start: .zero, end: CGPoint(x: 100, y: 0))), style: .init(strokeWidth: 4))
        #expect(line.hitTest(CGPoint(x: 50, y: 3), tolerance: 2) == true)
        #expect(line.hitTest(CGPoint(x: 50, y: 10), tolerance: 2) == false)
    }

    @Test func unfilledBoxHitsOnlyOnItsStroke() {
        var box = Annotation(kind: .box(Box(rect: CGRect(x: 0, y: 0, width: 100, height: 100), form: .rectangle)),
                             style: .init(strokeWidth: 2))
        #expect(box.hitTest(CGPoint(x: 50, y: 50), tolerance: 2) == false)
        #expect(box.hitTest(CGPoint(x: 0.5, y: 50), tolerance: 2) == true)
        box.style.fillColor = .yellow
        #expect(box.hitTest(CGPoint(x: 50, y: 50), tolerance: 2) == true)
    }

    @Test func boundsAndMove() {
        var line = Annotation(kind: .line(Line(start: CGPoint(x: 10, y: 20), end: CGPoint(x: 5, y: 50), arrow: true)))
        #expect(line.bounds == CGRect(x: 5, y: 20, width: 5, height: 30))
        line.move(by: CGVector(dx: 1, dy: -1))
        #expect(line.bounds.origin == CGPoint(x: 6, y: 19))
    }
}
