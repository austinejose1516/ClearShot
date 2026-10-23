import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct SelectionGeometryTests {
    @Test func normalizedRectWorksInAnyDragDirection() {
        let rect = SelectionGeometry.normalizedRect(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 10, y: 20))
        #expect(rect == CGRect(x: 10, y: 20, width: 90, height: 80))
    }

    @Test func tinyDragIsNotUsable() {
        #expect(SelectionGeometry.isUsable(CGRect(x: 0, y: 0, width: 2, height: 10)) == false)
        #expect(SelectionGeometry.isUsable(CGRect(x: 0, y: 0, width: 3, height: 3)) == true)
    }

    @Test func snappedRectCoversTheSelectionInWholePixels() {
        let rect = SelectionGeometry.snappedToPixels(CGRect(x: 10.4, y: 20.6, width: 100, height: 50),
                                                     scale: 2, within: CGSize(width: 1800, height: 1169))
        #expect(rect == CGRect(x: 10, y: 20.5, width: 100.5, height: 50.5))
    }

    @Test func snappedRectStaysInsideTheScreen() {
        let rect = SelectionGeometry.snappedToPixels(CGRect(x: 1750, y: 1100, width: 100, height: 100),
                                                     scale: 2, within: CGSize(width: 1800, height: 1169))
        #expect(rect == CGRect(x: 1750, y: 1100, width: 50, height: 69))
    }

    @Test func rectOnWholePixelsIsUnchanged() {
        let rect = SelectionGeometry.snappedToPixels(CGRect(x: 10, y: 20, width: 100, height: 50),
                                                     scale: 2, within: CGSize(width: 1800, height: 1169))
        #expect(rect == CGRect(x: 10, y: 20, width: 100, height: 50))
    }

    @Test func tagSitsBelowAndRightOfThePoint() {
        let origin = SelectionGeometry.tagOrigin(near: CGPoint(x: 100, y: 200), size: CGSize(width: 60, height: 20),
                                                 in: CGSize(width: 1800, height: 1169), gap: 14)
        #expect(origin == CGPoint(x: 114, y: 214))
    }

    @Test func tagFlipsLeftAndUpNearTheScreenEdge() {
        let origin = SelectionGeometry.tagOrigin(near: CGPoint(x: 1780, y: 1160), size: CGSize(width: 60, height: 20),
                                                 in: CGSize(width: 1800, height: 1169), gap: 14)
        #expect(origin == CGPoint(x: 1706, y: 1126))
    }

    @Test func gridShowsOnlyInABoxBigEnoughForIt() {
        #expect(SelectionGeometry.showsGrid(for: CGRect(x: 0, y: 0, width: 59, height: 200)) == false)
        #expect(SelectionGeometry.showsGrid(for: CGRect(x: 0, y: 0, width: 60, height: 60)) == true)
    }
}
