import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct EditorSessionTests {
    private func session() -> EditorSession {
        EditorSession(document: EditorDocument(baseImage: blankImage(width: 400, height: 300)))
    }

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /// One mouse drag through the points (a single point is a click).
    private func drag(_ session: EditorSession, _ points: CGPoint...) {
        for point in points { session.dragChanged(to: point, tolerance: 4) }
        session.dragEnded()
    }

    @Test func drawingAnArrowAddsOneSelectedUndoableArrow() {
        let s = session()
        s.tool = .arrow
        drag(s, p(10, 10), p(50, 50), p(100, 100))
        #expect(s.document.annotations.count == 1)
        let arrow = s.document.annotations[0]
        #expect(arrow.kind == .curve(Curve(start: p(10, 10), end: p(100, 100), arrow: true)))
        #expect(s.document.selection == [arrow.id])
        #expect(s.tool == .select)
        s.document.undo()
        #expect(s.document.annotations.isEmpty)
    }

    @Test func aClickWithADrawingToolAddsNothingAndHandsBackToThePointer() {
        for tool in [EditorTool.line, .arrow, .pen, .highlight, .rect, .ellipse, .bubble, .blur, .crop] {
            let s = session()
            s.tool = tool
            drag(s, p(10, 10))
            #expect(s.document.annotations.isEmpty, "\(tool)")
            #expect(s.document.canUndo == false, "\(tool)")
            #expect(s.tool == .select, "\(tool) should hand back to Select")
            #expect(s.cropDraft == nil)
        }
    }

    @Test func clickingAwayFromAPenStrokeDeselectsItAndHandsBackToThePointer() {
        let s = session()
        s.tool = .pen
        drag(s, p(10, 10), p(60, 10), p(110, 10))
        #expect(s.document.selection.count == 1 && s.tool == .pen)
        drag(s, p(200, 200))
        #expect(s.document.annotations.count == 1)
        #expect(s.document.selection.isEmpty)
        #expect(s.tool == .select)
    }

    @Test func newTextIsPlainAndTheStyleKeysFlipItWhileTyping() {
        let s = session()
        s.tool = .text
        drag(s, p(10, 10))
        s.editText("Hi")
        let plain = s.document.annotations[0].textContent
        #expect(plain?.fontSize == 24 && plain?.bold == false && plain?.italic == false && plain?.underline == false)
        s.apply(.italic(true))
        s.apply(.underline(true))
        let styled = s.document.annotations[0].textContent
        #expect(styled?.italic == true && styled?.underline == true && styled?.bold == false)
        #expect(s.shownValues.italic && s.shownValues.underline)
        s.finishTextEditing()
        // The next text keeps the style.
        s.tool = .text
        drag(s, p(10, 100))
        #expect(s.document.annotations[1].textContent?.italic == true)
    }

    @Test func pressingAShapeWithADrawingToolMovesItInsteadOfDrawing() {
        let s = session()
        s.tool = .arrow
        drag(s, p(10, 10), p(100, 10))
        s.document.selection = []
        s.tool = .arrow
        drag(s, p(50, 10), p(60, 30))
        #expect(s.document.annotations.count == 1)
        #expect(s.document.annotations[0].kind == .curve(Curve(start: p(20, 30), end: p(110, 30), arrow: true)))
    }

    @Test func aCornerDotResizesTheSelectedShapeWithAnyTool() {
        let s = session()
        s.tool = .rect
        drag(s, p(10, 10), p(50, 50))
        s.tool = .ellipse
        drag(s, p(50, 50), p(80, 90))
        #expect(s.document.annotations.count == 1)
        #expect(s.document.annotations[0].bounds == CGRect(x: 10, y: 10, width: 70, height: 80))
    }

    @Test func penKeepsEveryPointOfTheStroke() {
        let s = session()
        s.tool = .pen
        drag(s, p(0, 0), p(5, 0), p(10, 0), p(10, 5))
        guard case .freehand(let stroke) = s.document.annotations.first?.kind else {
            Issue.record("no stroke")
            return
        }
        #expect(stroke.points.count == 4)
    }

    @Test func aDrawnArrowStartsStraightAndItsMiddleDotBendsIt() {
        let s = session()
        s.tool = .arrow
        drag(s, p(0, 100), p(120, 60), p(200, 100))
        #expect(s.document.annotations[0].kind == .curve(Curve(start: p(0, 100), end: p(200, 100), arrow: true)))
        // Still selected, so the middle dot is live; it follows the pointer in both directions.
        drag(s, p(100, 100), p(100, 40), p(130, 40))
        guard case .curve(let curve) = s.document.annotations[0].kind else {
            Issue.record("no curve")
            return
        }
        #expect(curve.bend == -60 && curve.lean == 30)
        #expect(curve.middle == p(130, 40))
        s.document.undo()
        #expect(s.document.annotations[0].kind == .curve(Curve(start: p(0, 100), end: p(200, 100), arrow: true)))
    }

    @Test func bothEndsTickedBeforeDrawingGoesOntoTheNewArrow() {
        let s = session()
        s.tool = .arrow
        #expect(s.shownCapabilities.contains(.bothEnds))
        s.apply(.bothEnds(true))
        drag(s, p(0, 100), p(200, 100))
        #expect(s.document.annotations[0].kind == .curve(Curve(start: p(0, 100), end: p(200, 100), arrow: true, bothEnds: true)))
        #expect(s.shownValues.bothEnds)
    }

    @Test func theHighlighterHasItsOwnColourWidthAndOpacity() {
        let s = session()
        s.apply(.color(.blue))          // the shared colour, for arrows, pen and shapes
        s.tool = .highlight
        #expect(s.shownValues.color == .yellow && s.shownValues.opacity == 0.5)
        drag(s, p(0, 0), p(50, 0), p(100, 0))
        let highlight = s.document.annotations[0]
        #expect(highlight.kind == .freehand(Freehand(points: [p(0, 0), p(50, 0), p(100, 0)], form: .highlighter)))
        #expect(highlight.style.strokeColor == RGBAColor.yellow.withAlpha(0.5))
        #expect(highlight.style.strokeWidth == StyleValues.highlighter.width)
        #expect(s.tool == .highlight)

        // Recolouring the selected highlight changes the next highlight, not the next arrow or pen stroke.
        s.apply(.color(.green))
        s.tool = .pen
        drag(s, p(0, 50), p(50, 50))
        #expect(s.document.annotations[1].style.strokeColor == .blue)
        #expect(s.document.annotations[1].style.strokeWidth == Annotation.Style.defaultWidth)
        s.document.selection = []
        s.tool = .arrow
        #expect(s.shownValues.color == .blue)
        s.tool = .highlight
        #expect(s.shownValues.color == .green)
    }

    @Test func draggingWithTheTextToolKeepsTheToolbarSizeAndStartsEditing() {
        let s = session()
        s.tool = .text
        drag(s, p(10, 10), p(200, 70))
        let text = s.document.annotations[0]
        #expect(s.editingTextID == text.id)
        #expect(text.textContent?.fontSize == StyleValues().fontSize)
        #expect(text.textContent?.origin == p(10, 10))
        s.editText("Hello")
        s.finishTextEditing()
        #expect(s.editingTextID == nil)
        #expect(s.document.annotations[0].textContent?.text == "Hello")
        #expect(s.document.canUndo)
    }

    @Test func newTextLeftEmptyIsDropped() {
        let s = session()
        s.tool = .text
        drag(s, p(10, 10))
        s.editText("")
        s.finishTextEditing()
        #expect(s.document.annotations.isEmpty)
    }

    @Test func clickingSelectedTextEditsItAndDraggingItMovesIt() {
        let s = session()
        s.tool = .text
        drag(s, p(10, 10))
        s.editText("Hi")
        s.finishTextEditing()
        let id = s.document.annotations[0].id
        s.tool = .select
        let middle = p(s.document.annotations[0].bounds.midX, s.document.annotations[0].bounds.midY)

        drag(s, middle)
        #expect(s.editingTextID == id)
        s.finishTextEditing()

        drag(s, middle, p(middle.x + 40, middle.y))
        #expect(s.editingTextID == nil)
        let origin = s.document.annotations[0].textContent?.origin ?? .zero
        #expect(abs(origin.x - 50) < 0.001 && abs(origin.y - 10) < 0.001)
    }

    @Test func aDrawnBubbleStartsEditingItsText() {
        let s = session()
        s.tool = .bubble
        drag(s, p(10, 10), p(110, 60))
        #expect(s.editingTextID == s.document.annotations[0].id)
        s.editText("Hi")
        s.finishTextEditing()
        #expect(s.document.annotations[0].editableText == "Hi")
    }

    @Test func stepsNumberThemselvesAndUseTheStepSize() {
        let s = session()
        s.tool = .step
        s.apply(.stepSize(20))
        drag(s, p(30, 30))
        drag(s, p(150, 30))
        let steps = s.document.annotations.compactMap { annotation -> Step? in
            if case .step(let step) = annotation.kind { step } else { nil }
        }
        #expect(steps.map(\.number) == [1, 2])
        #expect(steps.allSatisfy { $0.radius == 20 })
    }

    @Test func cropDragThenApplyShrinksTheImage() {
        let s = session()
        s.tool = .crop
        drag(s, p(10, 10), p(110, 60))
        #expect(s.cropDraft == CGRect(x: 10, y: 10, width: 100, height: 50))
        s.applyCrop()
        #expect(s.document.imageSize == CGSize(width: 100, height: 50))
        #expect(s.cropDraft == nil)
        #expect(s.tool == .select)
    }

    @Test func aStyleChangeOnEverythingOnlyChangesWhatEachHas() {
        let s = session()
        s.document.add(Annotation(kind: .text(TextContent(text: "Hi", origin: .zero, fontSize: 20))))
        s.document.add(Annotation(kind: .line(Line(start: p(0, 100), end: p(100, 100), arrow: true))))
        s.selectAll()
        s.apply(.color(.blue))
        s.apply(.width(2))
        let text = s.document.annotations[0], arrow = s.document.annotations[1]
        #expect(text.textContent?.fontSize == 20)
        #expect(text.style.strokeColor == .blue)
        #expect(text.style.strokeWidth == Annotation.Style.defaultWidth)
        #expect(arrow.style.strokeColor == .blue)
        #expect(arrow.style.strokeWidth == 2)
    }

    @Test func aStyleChangeWithNothingSelectedOnlyAffectsNewShapes() {
        let s = session()
        s.apply(.width(2))
        s.tool = .line
        drag(s, p(0, 0), p(50, 0))
        #expect(s.document.annotations[0].style.strokeWidth == 2)
    }

    @Test func theToolbarShowsTheSelectionsValuesAndControls() {
        let s = session()
        s.document.add(Annotation(kind: .box(Box(rect: CGRect(x: 0, y: 0, width: 50, height: 50), form: .rectangle)),
                                  style: .init(strokeWidth: 4, fillColor: .red)))
        s.selectAll()
        #expect(s.shownCapabilities == [.color, .width, .fill, .corners])
        #expect(s.shownValues.width == 4)   // the selection's own width, not the default
        #expect(s.shownValues.fills)
        s.cancel()
        s.tool = .text
        #expect(s.shownCapabilities == EditorTool.text.capabilities)
    }

    @Test func cancelClearsSelectionCropAndTool() {
        let s = session()
        s.tool = .crop
        drag(s, p(10, 10), p(110, 60))
        s.cancel()
        #expect(s.cropDraft == nil)
        #expect(s.tool == .select)
        #expect(s.document.selection.isEmpty)
    }

    @Test func theCursorShowsWhatAPressWouldDo() {
        let s = session()
        s.tool = .rect
        drag(s, p(10, 10), p(50, 50))
        s.tool = .rect
        #expect(s.cursor(at: p(50, 50), tolerance: 4) == .resize(.bottomRight))
        #expect(s.cursor(at: p(10, 30), tolerance: 4) == .move)
        #expect(s.cursor(at: p(200, 200), tolerance: 4) == .tool(.rect))
    }

    @Test func finishingTextGoesBackToSelectSoTheNextClickAddsNothing() {
        let s = session()
        s.tool = .text
        drag(s, p(10, 10))
        s.editText("Hi")
        s.finishTextEditing()
        #expect(s.tool == .select)
        drag(s, p(300, 200))
        #expect(s.document.annotations.count == 1)
    }

    @Test func clickingAwayFromNewTextAlsoGoesBackToSelect() {
        let s = session()
        s.tool = .text
        drag(s, p(10, 10))
        s.editText("Hi")
        drag(s, p(300, 200))
        #expect(s.editingTextID == nil)
        #expect(s.tool == .select)
        #expect(s.document.annotations.count == 1)
    }

    @Test func finishingABubbleGoesBackToSelect() {
        let s = session()
        s.tool = .bubble
        drag(s, p(10, 10), p(110, 60))
        s.editText("Hi")
        s.finishTextEditing()
        #expect(s.tool == .select)
    }

    @Test func textCanSitInThePaddingOutsideTheImage() {
        let s = session()
        s.tool = .text
        drag(s, p(20, -60))
        s.editText("Header")
        s.finishTextEditing()
        #expect(s.document.annotations[0].textContent?.origin == p(20, -60))
        s.tool = .select
        drag(s, p(30, -50))
        #expect(s.editingTextID == s.document.annotations[0].id)
    }

    @Test func shapeToolsHandBackToSelectButStrokesStepAndBlurStayOn() {
        for tool in [EditorTool.line, .arrow, .rect, .ellipse, .bubble] {
            let s = session()
            s.tool = tool
            drag(s, p(10, 10), p(120, 80))
            s.finishTextEditing()
            #expect(s.tool == .select, "\(tool) should hand back to Select")
        }
        for tool in [EditorTool.pen, .highlight, .step, .blur] {
            let s = session()
            s.tool = tool
            drag(s, p(10, 10), p(120, 80))
            #expect(s.tool == tool, "\(tool) should stay on")
        }
    }

    @Test func thePointerSelectsAnUnfilledBoxByClickingInside() {
        let s = session()
        s.tool = .ellipse
        drag(s, p(10, 10), p(110, 110))
        s.document.selection = []
        drag(s, p(60, 60))
        #expect(s.document.selection == [s.document.annotations[0].id])
        drag(s, p(60, 60), p(80, 60))
        #expect(s.document.annotations[0].bounds.origin == p(30, 10))
    }

    @Test func aDrawingToolStillDrawsInsideAnUnfilledBox() {
        let s = session()
        s.tool = .rect
        drag(s, p(10, 10), p(200, 200))
        s.tool = .rect
        drag(s, p(50, 50), p(100, 100))
        #expect(s.document.annotations.count == 2)
    }

    @Test func newRectanglesUseTheChosenCorners() {
        let s = session()
        s.apply(.cornerRadius(16))
        s.tool = .rect
        drag(s, p(10, 10), p(110, 60))
        #expect(s.document.annotations[0].kind == .box(Box(rect: CGRect(x: 10, y: 10, width: 100, height: 50), form: .rectangle, cornerRadius: 16)))
    }

    @Test func aSliderDragIsOneUndoStep() {
        let s = session()
        s.tool = .line
        drag(s, p(0, 0), p(100, 0))
        s.apply(.width(10), live: true)
        s.apply(.width(20), live: true)
        s.endLiveChange()
        #expect(s.document.annotations[0].style.strokeWidth == 20)
        s.document.undo()
        #expect(s.document.annotations[0].style.strokeWidth == Annotation.Style.defaultWidth)
    }
}
