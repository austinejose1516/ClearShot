import CoreGraphics
import Testing
@testable import ScreenshotXXCore

@Suite struct TextContentTests {
    private func text(_ string: String = "Hello", size: CGFloat = 20, bold: Bool = true, boxed: Bool = false) -> TextContent {
        TextContent(text: string, origin: CGPoint(x: 100, y: 100), fontSize: size, bold: bold, boxed: boxed)
    }

    @Test func biggerFontMeansABiggerBox() {
        let small = text(size: 20).size, big = text(size: 40).size
        #expect(big.width > small.width * 1.8)
        #expect(big.height > small.height * 1.8)
    }

    @Test func twoLinesAreTallerThanOne() {
        #expect(text("Hello\nHello").size.height > text("Hello").size.height * 1.8)
    }

    @Test func boldIsWiderThanRegular() {
        #expect(text(bold: true).size.width > text(bold: false).size.width)
    }

    @Test func boxedAddsPaddingOnEverySide() {
        let plain = text(boxed: false), boxed = text(boxed: true)
        #expect(boxed.size.width == plain.size.width + 2 * boxed.padding.width)
        #expect(boxed.size.height == plain.size.height + 2 * boxed.padding.height)
    }

    @Test func emptyTextStillHasOneLineOfHeight() {
        #expect(text("").size.height == text("A").size.height)
    }

    @Test func frameStartsAtTheOrigin() {
        let content = text()
        #expect(content.frame == CGRect(origin: CGPoint(x: 100, y: 100), size: content.size))
    }

    @Test func cornerDragScalesTheFontAndKeepsTheOppositeCorner() {
        var grow = text(size: 20)
        let before = grow.frame
        grow.drag(.bottomRight, to: CGPoint(x: before.minX + before.width * 2, y: before.maxY))
        #expect(abs(grow.fontSize - 40) < 2)
        #expect(grow.frame.origin == before.origin)

        var shrink = text(size: 40)
        let start = shrink.frame
        shrink.drag(.topLeft, to: CGPoint(x: start.midX, y: start.midY))
        #expect(shrink.fontSize < 25)
        #expect(abs(shrink.frame.maxX - start.maxX) < 0.001)
        #expect(abs(shrink.frame.maxY - start.maxY) < 0.001)
    }

    @Test func fontSizeFromADraggedBoxHeight() {
        #expect(TextContent.fontSize(forBoxHeight: 60, boxed: false) == 50)
        #expect(TextContent.fontSize(forBoxHeight: 60, boxed: true) == 40)
        #expect(TextContent.fontSize(forBoxHeight: 2, boxed: false) == TextContent.minimumFontSize)
    }

    @Test func textHitsInsideItsFrameAndMoves() {
        var note = Annotation(kind: .text(text()))
        let frame = note.bounds
        #expect(note.hitTest(CGPoint(x: frame.midX, y: frame.midY), tolerance: 2) == true)
        #expect(note.hitTest(CGPoint(x: 10, y: 10), tolerance: 2) == false)
        note.move(by: CGVector(dx: -100, dy: -100))
        #expect(note.bounds.origin == .zero)
    }
}
