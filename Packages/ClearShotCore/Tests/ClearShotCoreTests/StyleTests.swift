import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct StyleTests {
    @Test func changesOnlyTouchWhatTheAnnotationHas() {
        var text = Annotation(kind: .text(TextContent(text: "Hi", origin: .zero, fontSize: 20)))
        text.apply(.width(30))
        #expect(text.style.strokeWidth == Annotation.Style.defaultWidth)
        text.apply(.fontSize(40))
        #expect(text.textContent?.fontSize == 40)

        var line = Annotation(kind: .line(Line(start: .zero, end: CGPoint(x: 10, y: 0))))
        line.apply(.fontSize(40))
        line.apply(.arrow(true))
        #expect(line.kind == .line(Line(start: .zero, end: CGPoint(x: 10, y: 0), arrow: true)))
        line.apply(.bothEnds(true))     // a plain line has no second head to add
        #expect(line.kind == .line(Line(start: .zero, end: CGPoint(x: 10, y: 0), arrow: true)))

        var arrow = Annotation(kind: .curve(Curve(start: .zero, end: CGPoint(x: 10, y: 0), arrow: true)))
        arrow.apply(.bothEnds(true))
        #expect(arrow.kind == .curve(Curve(start: .zero, end: CGPoint(x: 10, y: 0), arrow: true, bothEnds: true)))
    }

    @Test func colourKeepsOpacityAndFillFollowsTheColour() {
        var box = Annotation(kind: .box(Box(rect: CGRect(x: 0, y: 0, width: 10, height: 10), form: .rectangle)))
        box.apply(.opacity(0.5))
        box.apply(.fill(true))
        box.apply(.color(.blue))
        #expect(box.style.strokeColor == RGBAColor.blue.withAlpha(0.5))
        #expect(box.style.fillColor == RGBAColor.blue.withAlpha(0.5))
        box.apply(.fill(false))
        #expect(box.style.fillColor == nil)
    }

    @Test func blurIgnoresColourButTakesItsMode() {
        var blur = Annotation(kind: .blur(Blur(rect: .zero, mode: .pixelate)))
        let before = blur.style
        blur.apply(.color(.green))
        blur.apply(.blurMode(.blur))
        #expect(blur.style == before)
        #expect(blur.kind == .blur(Blur(rect: .zero, mode: .blur)))
    }

    @Test func valuesShowTheAnnotationsOwnStyle() {
        var text = Annotation(kind: .text(TextContent(text: "Hi", origin: .zero, fontSize: 20, bold: true, italic: true,
                                                      underline: true, boxed: true)))
        text.style = Annotation.Style(strokeColor: RGBAColor.purple.withAlpha(0.75), strokeWidth: 4)
        let shown = StyleValues().reading(text)
        #expect(shown.color == .purple)
        #expect(shown.opacity == 0.75)
        #expect(shown.fontSize == 20)
        #expect(shown.bold && shown.italic && shown.underline && shown.boxed)
    }

    @Test func newTextIsBoxedButOtherwisePlain() {
        let values = StyleValues()
        #expect(values.bold == false && values.italic == false && values.underline == false && values.boxed)
    }

    @Test func newShapesGetFillOnlyWhenTheyCanBeFilled() {
        var values = StyleValues()
        values.apply(.fill(true))
        values.apply(.opacity(0.5))
        #expect(values.style(canFill: true).fillColor == RGBAColor.red.withAlpha(0.5))
        #expect(values.style(canFill: false).fillColor == nil)
    }

    @Test func stepSizeChangesOnlySteps() {
        var step = Annotation(kind: .step(Step(number: 1, center: .zero, radius: 36)))
        step.apply(.stepSize(64))
        step.apply(.width(2))
        #expect(step.kind == .step(Step(number: 1, center: .zero, radius: 64)))
        #expect(StyleValues().reading(step).stepRadius == 64)
    }

    @Test func cornersRoundRectanglesOnly() {
        var rectangle = Annotation(kind: .box(Box(rect: CGRect(x: 0, y: 0, width: 50, height: 50), form: .rectangle)))
        var ellipse = Annotation(kind: .box(Box(rect: CGRect(x: 0, y: 0, width: 50, height: 50), form: .ellipse)))
        #expect(rectangle.capabilities.contains(.corners))
        #expect(ellipse.capabilities.contains(.corners) == false)
        rectangle.apply(.cornerRadius(12))
        ellipse.apply(.cornerRadius(12))
        #expect(StyleValues().reading(rectangle).cornerRadius == 12)
        #expect(ellipse.kind == .box(Box(rect: CGRect(x: 0, y: 0, width: 50, height: 50), form: .ellipse)))
    }

    @Test func stepsStartAtFortyPixels() {
        #expect(StyleValues().stepRadius * 2 == 40)
    }

    @Test func theHighlighterStartsYellowHalfSeeThroughAndWide() {
        let values = StyleValues.highlighter
        #expect(values.color == .yellow && values.opacity == 0.5 && values.width == 32)
        #expect(values.style(canFill: false).strokeColor == RGBAColor.yellow.withAlpha(0.5))
        #expect(StyleValues.widthRange.contains(values.width))
    }

    @Test func defaultThicknessIsNormalNotHeavy() {
        #expect(StyleValues().width == 4)
        #expect(Annotation.Style().strokeWidth == 4)
    }

    @Test func thePaletteHasNineColoursIncludingPink() {
        #expect(RGBAColor.presets.count == 9)
        #expect(RGBAColor.presets.contains(.pink))
    }
}
