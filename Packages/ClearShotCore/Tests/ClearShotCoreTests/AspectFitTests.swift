import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct AspectFitTests {
    @Test func aWidePictureTakesTheFullWidthAndIsCentred() {
        let rect = AspectFit.rect(for: CGSize(width: 400, height: 100), in: CGRect(x: 10, y: 20, width: 200, height: 200))
        #expect(rect == CGRect(x: 10, y: 95, width: 200, height: 50))
    }

    @Test func aTallPictureTakesTheFullHeight() {
        let rect = AspectFit.rect(for: CGSize(width: 50, height: 100), in: CGRect(x: 0, y: 0, width: 300, height: 200))
        #expect(rect == CGRect(x: 100, y: 0, width: 100, height: 200))
    }

    @Test func aSmallPictureIsEnlarged() {
        let rect = AspectFit.rect(for: CGSize(width: 10, height: 10), in: CGRect(x: 0, y: 0, width: 100, height: 50))
        #expect(rect == CGRect(x: 25, y: 0, width: 50, height: 50))
    }

    @Test func nothingToFitGivesTheBoxCentre() {
        let rect = AspectFit.rect(for: .zero, in: CGRect(x: 0, y: 0, width: 100, height: 50))
        #expect(rect == CGRect(x: 50, y: 25, width: 0, height: 0))
    }
}
