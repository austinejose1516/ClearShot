import CoreGraphics
import Testing
@testable import ScreenshotXXCore

@Suite struct FigureTests {
    @Test func lineEndsAreItsHandles() {
        var line = Line(start: .zero, end: CGPoint(x: 10, y: 0))
        #expect(line.handles.map(\.kind) == [.start, .end])
        line.drag(.end, to: CGPoint(x: 5, y: 5))
        #expect(line.end == CGPoint(x: 5, y: 5))
        #expect(line.start == .zero)
    }

    @Test func boxCornerDragKeepsTheOppositeCorner() {
        var box = Box(rect: CGRect(x: 10, y: 10, width: 100, height: 50), form: .rectangle)
        #expect(box.handles.map(\.kind) == [.topLeft, .topRight, .bottomLeft, .bottomRight])
        box.drag(.topLeft, to: .zero)
        #expect(box.rect == CGRect(x: 0, y: 0, width: 110, height: 60))
        box.drag(.bottomRight, to: CGPoint(x: -10, y: -10))
        #expect(box.rect == CGRect(x: -10, y: -10, width: 10, height: 10))
    }

    @Test func aNewCurveIsStraightAndItsMiddleDotGoesWhereverItIsDragged() {
        var curve = Curve(start: .zero, end: CGPoint(x: 100, y: 0), arrow: true)
        #expect(curve.handles.map(\.kind) == [.start, .middle, .end])
        #expect(curve.middle == CGPoint(x: 50, y: 0))
        #expect(curve.control == CGPoint(x: 50, y: 0))

        curve.drag(.middle, to: CGPoint(x: 50, y: 40))
        #expect(curve.bend == 40 && curve.lean == 0)
        #expect(curve.middle == CGPoint(x: 50, y: 40))     // the dot stays on the curve…
        #expect(curve.control == CGPoint(x: 50, y: 80))    // …so the control point is twice as far out
        #expect(CurveGeometry.point(start: curve.start, control: curve.control, end: curve.end, t: 0.5) == curve.middle)
        #expect(curve.bounds.maxY == 40)

        // The other side, and off-centre: the dot lands under the pointer and the curve leans with it.
        curve.drag(.middle, to: CGPoint(x: 70, y: -40))
        #expect(curve.bend == -40 && curve.lean == 20)
        #expect(curve.middle == CGPoint(x: 70, y: -40))
        #expect(curve.control == CGPoint(x: 90, y: -80))
        #expect(CurveGeometry.point(start: curve.start, control: curve.control, end: curve.end, t: 0.5) == curve.middle)
    }

    @Test func movingACurvesEndKeepsItsShape() {
        var curve = Curve(start: .zero, end: CGPoint(x: 100, y: 0), bend: 30, lean: 10, arrow: true)
        curve.drag(.end, to: CGPoint(x: 0, y: 100))      // the line turns 90°, so the dot turns with it
        #expect(curve.bend == 30 && curve.lean == 10)
        #expect(abs(curve.middle.x - -30) < 0.001 && abs(curve.middle.y - 60) < 0.001)
        curve.move(by: CGVector(dx: 10, dy: 10))
        #expect(curve.bend == 30 && curve.lean == 10)
        #expect(curve.start == CGPoint(x: 10, y: 10))
    }

    @Test func aHighlighterStrokeIsAFreehandStrokeInAnotherForm() {
        let points = [CGPoint.zero, CGPoint(x: 10, y: 0)]
        #expect(Annotation(kind: .freehand(Freehand(points: points, form: .highlighter))).isHighlight)
        #expect(Annotation(kind: .freehand(Freehand(points: points))).isHighlight == false)
        #expect(Freehand(points: points, form: .highlighter).capabilities == Freehand(points: points).capabilities)
    }

    @Test func bubbleTailHandleMovesOnlyTheTail() {
        var bubble = Bubble(rect: CGRect(x: 0, y: 0, width: 200, height: 100), tail: CGPoint(x: 50, y: 160))
        #expect(bubble.handles.last?.kind == .tail)
        bubble.drag(.tail, to: CGPoint(x: 300, y: 50))
        #expect(bubble.tail == CGPoint(x: 300, y: 50))
        #expect(bubble.rect == CGRect(x: 0, y: 0, width: 200, height: 100))
    }

    @Test func bubbleTextSitsInsideTheBox() {
        let bubble = Bubble(rect: CGRect(x: 0, y: 0, width: 200, height: 100), tail: .zero, fontSize: 20)
        #expect(bubble.textRect == CGRect(x: 8, y: 6, width: 184, height: 88))
    }

    @Test func drawnBubbleHasItsTailBelowAndFontFromHeight() {
        let bubble = Bubble.drawn(from: CGPoint(x: 100, y: 100), to: .zero)
        #expect(bubble.rect == CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(bubble.tail == CGPoint(x: 25, y: 150))
        #expect(bubble.fontSize == 25)
    }

    @Test func blurResizesByCorners() {
        var blur = Blur(rect: CGRect(x: 0, y: 0, width: 10, height: 10), mode: .pixelate)
        blur.drag(.bottomRight, to: CGPoint(x: 40, y: 30))
        #expect(blur.rect == CGRect(x: 0, y: 0, width: 40, height: 30))
    }

    @Test func tinyShapesAndSinglePointScribblesAreTooSmall() {
        #expect(Box(rect: CGRect(x: 0, y: 0, width: 2, height: 2), form: .ellipse).isTooSmall)
        #expect(Box(rect: CGRect(x: 0, y: 0, width: 3, height: 1), form: .ellipse).isTooSmall == false)
        #expect(Freehand(points: [.zero]).isTooSmall)
        #expect(Freehand(points: [.zero, CGPoint(x: 1, y: 0)]).isTooSmall == false)
    }

    @Test func onlyTextAndBubblesHaveEditableText() {
        #expect(Bubble(rect: .zero, tail: .zero, text: "Hi").editableText == "Hi")
        #expect(TextContent(text: "Yo", origin: .zero).editableText == "Yo")
        #expect(Line(start: .zero, end: .zero).editableText == nil)
        var bubble = Bubble(rect: .zero, tail: .zero)
        bubble.setEditableText("New")
        #expect(bubble.text == "New")
    }

    @Test func stepCornerDragResizesAroundItsCentre() {
        var step = Step(number: 2, center: CGPoint(x: 100, y: 100), radius: 20)
        #expect(step.handles.count == 4)
        step.drag(.bottomRight, to: CGPoint(x: 150, y: 130))
        #expect(step.radius == 50)
        #expect(step.center == CGPoint(x: 100, y: 100))
        step.drag(.topLeft, to: CGPoint(x: 99, y: 99))
        #expect(step.radius == Step.minimumRadius)
    }
}
