import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct SidePanelLayoutTests {
    private let visible = CGRect(x: 0, y: 0, width: 1800, height: 1100)

    @Test func goesRightOfTheAreaWhenThereIsRoom() {
        let area = CGRect(x: 200, y: 300, width: 800, height: 500)
        let frame = SidePanelLayout.frame(width: 120, beside: area, in: visible)
        #expect(frame == CGRect(x: 1012, y: 300, width: 120, height: 500))
    }

    @Test func goesLeftWhenTheRightIsFull() {
        let area = CGRect(x: 900, y: 300, width: 850, height: 500)
        let frame = SidePanelLayout.frame(width: 120, beside: area, in: visible)
        #expect(frame.minX == CGFloat(900 - 12 - 120))
    }

    @Test func goesInsideTheRightEdgeWhenNeitherSideHasRoom() {
        let frame = SidePanelLayout.frame(width: 120, beside: visible, in: visible)
        #expect(frame.maxX == CGFloat(1800 - 12))
        #expect(frame.height == CGFloat(1100 - 2 * 12))
    }

    @Test func staysOnTheVisibleScreenAndIsNeverTiny() {
        let low = CGRect(x: 200, y: 0, width: 400, height: 60)
        let frame = SidePanelLayout.frame(width: 120, beside: low, in: visible)
        #expect(frame.height == SidePanelLayout.minimumHeight)
        #expect(frame.minY == 0)
    }
}
