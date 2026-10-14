import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct ScreenRegionTests {
    @Test func pixelSizeScalesThePoints() {
        let region = ScreenRegion(displayID: 1, quartzRect: CGRect(x: 100, y: 50, width: 640.4, height: 480.6), scale: 2)
        #expect(region.pixelSize == CGSize(width: 1281, height: 961))
        #expect(ScreenRegion(displayID: 1, quartzRect: CGRect(x: 0, y: 0, width: 640, height: 480), scale: 1).pixelSize == CGSize(width: 640, height: 480))
    }

    @Test func centreIsWhereScrollEventsGo() {
        let region = ScreenRegion(displayID: 1, quartzRect: CGRect(x: 100, y: 50, width: 640, height: 480), scale: 2)
        #expect(region.center == CGPoint(x: 420, y: 290))
    }

    @Test func rectInsideItsDisplayDropsTheDisplayOrigin() {
        let region = ScreenRegion(displayID: 2, quartzRect: CGRect(x: 2000, y: 300, width: 400, height: 200), scale: 1)
        #expect(region.rect(inDisplay: CGRect(x: 1800, y: 0, width: 1920, height: 1080)) == CGRect(x: 200, y: 300, width: 400, height: 200))
    }
}
