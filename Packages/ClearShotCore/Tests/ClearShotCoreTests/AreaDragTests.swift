import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct AreaDragTests {
    @Test func boxFollowsTheMouseFromWhereItWentDown() {
        let drag = AreaDrag()
        drag.begin(at: CGPoint(x: 100, y: 100))
        drag.move(to: CGPoint(x: 40, y: 160))
        #expect(drag.isActive)
        #expect(drag.rect == CGRect(x: 40, y: 100, width: 60, height: 60))
    }

    @Test func endGivesTheBoxAndClearsIt() {
        let drag = AreaDrag()
        drag.begin(at: CGPoint(x: 10, y: 20))
        drag.move(to: CGPoint(x: 50, y: 50))
        #expect(drag.end(at: CGPoint(x: 110, y: 70)) == CGRect(x: 10, y: 20, width: 100, height: 50))
        #expect(drag.isActive == false)
        #expect(drag.rect == nil)
    }

    @Test func aClickEndsWithNoBox() {
        let drag = AreaDrag()
        drag.begin(at: CGPoint(x: 10, y: 20))
        #expect(drag.end(at: CGPoint(x: 11, y: 21)) == nil)
    }

    @Test func movesAndEndsWithoutABeginDoNothing() {
        let drag = AreaDrag()
        drag.move(to: CGPoint(x: 5, y: 5))
        #expect(drag.rect == nil)
        #expect(drag.end(at: CGPoint(x: 200, y: 200)) == nil)
    }
}
