import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct ScreenCoordinatesTests {
    @Test func appKitPointFlipsToQuartz() {
        let p = ScreenCoordinates.quartzPoint(fromAppKit: CGPoint(x: 100, y: 100), primaryHeight: 1169)
        #expect(p == CGPoint(x: 100, y: 1069))
    }

    @Test func appKitRectFlipsToQuartz() {
        let r = ScreenCoordinates.quartzRect(fromAppKit: CGRect(x: 0, y: 0, width: 1800, height: 25), primaryHeight: 1169)
        #expect(r == CGRect(x: 0, y: 1144, width: 1800, height: 25))
    }

    @Test func quartzRectBecomesLocalToItsScreen() {
        let r = ScreenCoordinates.viewRect(fromQuartz: CGRect(x: 2000, y: 300, width: 400, height: 200),
                                           screenQuartzFrame: CGRect(x: 1800, y: 0, width: 1920, height: 1080))
        #expect(r == CGRect(x: 200, y: 300, width: 400, height: 200))
    }

    @Test func viewRectGoesBackToQuartz() {
        let r = ScreenCoordinates.quartzRect(fromView: CGRect(x: 200, y: 300, width: 400, height: 200),
                                             screenQuartzFrame: CGRect(x: 1800, y: 0, width: 1920, height: 1080))
        #expect(r == CGRect(x: 2000, y: 300, width: 400, height: 200))
    }
}
