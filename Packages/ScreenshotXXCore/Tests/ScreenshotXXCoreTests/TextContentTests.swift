import CoreGraphics
import Testing
@testable import ScreenshotXXCore

@Suite struct TextContentTests {
    @Test func estimatedSizeComesFromTheLongestLine() {
        let content = TextContent(text: "Hello\nHi", origin: .zero, fontSize: 20)
        #expect(content.estimatedSize == CGSize(width: 55, height: 48))
        #expect(content.frame.size == content.estimatedSize)
    }

    @Test func measuredSizeWinsOnceTheViewReportsIt() {
        var content = TextContent(text: "Hello", origin: CGPoint(x: 10, y: 20), fontSize: 20)
        content.measuredSize = CGSize(width: 100, height: 40)
        #expect(content.frame == CGRect(x: 10, y: 20, width: 100, height: 40))
    }

    @Test func scalingToANewWidthScalesTheFont() {
        var content = TextContent(text: "Hello", origin: .zero, fontSize: 20)
        content.measuredSize = CGSize(width: 100, height: 40)
        let bigger = content.scaled(toWidth: 200)
        #expect(bigger.fontSize == 40)
        #expect(bigger.measuredSize == CGSize(width: 200, height: 80))
        #expect(content.scaled(toWidth: 5).fontSize >= TextContent.minimumFontSize)
    }

    @Test func textAnnotationHitsInsideItsFrameAndMoves() {
        var content = TextContent(text: "Hi", origin: CGPoint(x: 100, y: 100), fontSize: 20)
        content.measuredSize = CGSize(width: 60, height: 30)
        var note = Annotation(kind: .text(content))
        #expect(note.hitTest(CGPoint(x: 130, y: 115), tolerance: 2) == true)
        #expect(note.hitTest(CGPoint(x: 10, y: 10), tolerance: 2) == false)
        note.move(by: CGVector(dx: -100, dy: -100))
        #expect(note.bounds.origin == .zero)
    }

    @Test func fontSizeFromADraggedBoxHeight() {
        #expect(TextContent.fontSize(forBoxHeight: 60, boxed: false) == 50)
        #expect(TextContent.fontSize(forBoxHeight: 60, boxed: true) == 40)
        #expect(TextContent.fontSize(forBoxHeight: 2, boxed: false) == TextContent.minimumFontSize)
    }
}
