import CoreGraphics
import Testing
@testable import ScreenshotXXCore

@Suite struct SelectionGeometryTests {
    @Test func normalizedRectWorksInAnyDragDirection() {
        let rect = SelectionGeometry.normalizedRect(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 10, y: 20))
        #expect(rect == CGRect(x: 10, y: 20, width: 90, height: 80))
    }

    @Test func tinyDragIsNotUsable() {
        #expect(SelectionGeometry.isUsable(CGRect(x: 0, y: 0, width: 2, height: 10)) == false)
        #expect(SelectionGeometry.isUsable(CGRect(x: 0, y: 0, width: 3, height: 3)) == true)
    }

    @Test func pixelRectScalesByImageOverView() {
        let rect = SelectionGeometry.pixelRect(viewRect: CGRect(x: 10, y: 20, width: 100, height: 50),
                                               viewSize: CGSize(width: 1800, height: 1169),
                                               imageSize: CGSize(width: 3600, height: 2338))
        #expect(rect == CGRect(x: 20, y: 40, width: 200, height: 100))
    }

    @Test func pixelRectIsClampedToTheImage() {
        let rect = SelectionGeometry.pixelRect(viewRect: CGRect(x: 1750, y: 1100, width: 100, height: 100),
                                               viewSize: CGSize(width: 1800, height: 1169),
                                               imageSize: CGSize(width: 3600, height: 2338))
        #expect(rect == CGRect(x: 3500, y: 2200, width: 100, height: 138))
    }

    @Test func pixelRectUsesWholePixelsThatCoverTheSelection() {
        let rect = SelectionGeometry.pixelRect(viewRect: CGRect(x: 10.4, y: 20.6, width: 100, height: 50),
                                               viewSize: CGSize(width: 1800, height: 1169),
                                               imageSize: CGSize(width: 3600, height: 2338))
        #expect(rect == CGRect(x: 20, y: 41, width: 201, height: 101))
    }
}
