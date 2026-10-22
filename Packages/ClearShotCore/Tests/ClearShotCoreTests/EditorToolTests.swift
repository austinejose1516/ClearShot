import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct EditorToolTests {
    private let start = CGPoint(x: 100, y: 100), end = CGPoint(x: 0, y: 50)

    @Test func dragToolsDrawTheirShape() {
        let values = StyleValues()
        #expect(EditorTool.line.figure(from: start, to: end, values: values)?.asKind == .line(Line(start: start, end: end)))
        #expect(EditorTool.arrow.figure(from: start, to: end, values: values)?.asKind == .curve(Curve(start: start, end: end, arrow: true)))
        #expect(EditorTool.ellipse.figure(from: start, to: end, values: values)?.asKind
            == .box(Box(rect: CGRect(x: 0, y: 50, width: 100, height: 50), form: .ellipse)))
        #expect(EditorTool.bubble.figure(from: start, to: end, values: values)?.asKind == .bubble(Bubble.drawn(from: start, to: end, fontSize: values.fontSize)))
    }

    @Test func blurUsesTheChosenMode() {
        var values = StyleValues()
        values.apply(.blurMode(.blur))
        #expect(EditorTool.blur.figure(from: start, to: end, values: values)?.asKind
            == .blur(Blur(rect: CGRect(x: 0, y: 50, width: 100, height: 50), mode: .blur)))
    }

    @Test func theOneArrowToolIsTheBendableOneBehindTheStraightArrowIcon() {
        let drawsACurve = EditorTool.allCases.filter {
            if case .curve = $0.figure(from: start, to: end, values: StyleValues())?.asKind { true } else { false }
        }
        #expect(drawsACurve == [.arrow])
        #expect(EditorTool.arrow.symbol == "arrow.up.right")
    }

    @Test func bothEndsIsOfferedByTheArrowToolAndGoesOntoNewArrows() {
        #expect(EditorTool.arrow.capabilities.contains(.bothEnds))
        var values = StyleValues()
        values.apply(.bothEnds(true))
        #expect(EditorTool.arrow.figure(from: start, to: end, values: values)?.asKind
            == .curve(Curve(start: start, end: end, arrow: true, bothEnds: true)))
    }

    @Test func shiftConstrainsWhatADragDraws() {
        let values = StyleValues()
        #expect(EditorTool.rect.figure(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 110, y: 60), values: values, constrained: true)?.bounds
            == CGRect(x: 10, y: 10, width: 100, height: 100))
        #expect(EditorTool.ellipse.figure(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 40, y: 160), values: values, constrained: true)?.bounds
            == CGRect(x: 40, y: 100, width: 60, height: 60))
        let line = EditorTool.line.figure(from: .zero, to: CGPoint(x: 100, y: 90), values: values, constrained: true) as? Line
        #expect(line.map { abs($0.end.x - $0.end.y) < 0.001 && abs(hypot($0.end.x, $0.end.y) - hypot(100, 90)) < 0.001 } == true)
        // Bubbles are not constrained.
        #expect(EditorTool.bubble.figure(from: .zero, to: CGPoint(x: 100, y: 50), values: values, constrained: true)?.bounds.width == 100)
    }

    @Test func clickAndSpecialToolsDoNotDrawByDragging() {
        for tool in [EditorTool.select, .pen, .highlight, .text, .step, .crop] {
            #expect(tool.figure(from: start, to: end, values: StyleValues()) == nil)
        }
    }

    @Test func widthIsOfferedOnlyWhereItDrawsAStroke() {
        let withWidth = EditorTool.allCases.filter { $0.capabilities.contains(.width) }
        #expect(withWidth == [.line, .arrow, .pen, .highlight, .rect, .ellipse, .bubble])
    }

    @Test func strokesAndCropNeverGrabExistingShapes() {
        #expect(EditorTool.allCases.filter { !$0.grabsExisting } == [.pen, .highlight, .crop])
    }

    @Test func everyToolHasAHint() {
        #expect(EditorTool.allCases.allSatisfy { !$0.hint.isEmpty && !$0.title.isEmpty && !$0.symbol.isEmpty })
    }

    @Test func toolbarGroupsHoldEveryToolExactlyOnce() {
        let grouped = EditorTool.groups.flatMap { $0 }
        #expect(grouped.count == EditorTool.allCases.count)
        #expect(Set(grouped) == Set(EditorTool.allCases))
        #expect(EditorTool.groups.first == [.select])
    }
}
