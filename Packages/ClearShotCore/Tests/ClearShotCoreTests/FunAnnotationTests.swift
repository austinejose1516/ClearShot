import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct FunAnnotationTests {
    @Test func blurRegionIsHitInsideAndMoves() {
        var blur = Annotation(kind: .blur(Blur(rect: CGRect(x: 10, y: 10, width: 100, height: 50), mode: .pixelate)))
        #expect(blur.bounds == CGRect(x: 10, y: 10, width: 100, height: 50))
        #expect(blur.hitTest(CGPoint(x: 50, y: 30), tolerance: 2) == true)
        #expect(blur.hitTest(CGPoint(x: 200, y: 200), tolerance: 2) == false)
        blur.move(by: CGVector(dx: 5, dy: 5))
        #expect(blur.bounds.origin == CGPoint(x: 15, y: 15))
    }

    @Test func stepIsACircleAndNumbersContinue() {
        let doc = EditorDocument(baseImage: blankImage())
        #expect(doc.nextStepNumber == 1)
        var step = Annotation(kind: .step(Step(number: 1, center: CGPoint(x: 100, y: 100), radius: 30)))
        #expect(step.bounds == CGRect(x: 70, y: 70, width: 60, height: 60))
        #expect(step.hitTest(CGPoint(x: 120, y: 100), tolerance: 2) == true)
        #expect(step.hitTest(CGPoint(x: 140, y: 100), tolerance: 2) == false)
        step.move(by: CGVector(dx: -100, dy: 0))
        #expect(step.bounds.midX == 0)
        doc.add(step)
        doc.add(Annotation(kind: .step(Step(number: 7, center: .zero, radius: 30))))
        #expect(doc.nextStepNumber == 8)
    }

    @Test func bubbleIncludesItsTailAndMovesAsOne() {
        var bubble = Annotation(kind: .bubble(Bubble(rect: CGRect(x: 0, y: 0, width: 200, height: 100),
                                                     tail: CGPoint(x: 50, y: 160), text: "Hi", fontSize: 28)))
        #expect(bubble.bounds == CGRect(x: 0, y: 0, width: 200, height: 160))
        #expect(bubble.hitTest(CGPoint(x: 100, y: 50), tolerance: 2) == true)
        #expect(bubble.hitTest(CGPoint(x: 50, y: 158), tolerance: 2) == true)
        #expect(bubble.hitTest(CGPoint(x: 190, y: 150), tolerance: 2) == false)
        bubble.move(by: CGVector(dx: 10, dy: 0))
        #expect(bubble.kind == .bubble(Bubble(rect: CGRect(x: 10, y: 0, width: 200, height: 100),
                                              tail: CGPoint(x: 60, y: 160), text: "Hi", fontSize: 28)))
    }
}
