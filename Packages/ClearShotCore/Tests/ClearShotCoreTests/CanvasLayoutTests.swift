import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct CanvasLayoutTests {
    private let image = CGSize(width: 1200, height: 800)

    @Test func noFrameMeansCanvasEqualsImage() {
        let layout = CanvasLayout(imageSize: image, frame: FrameStyle())
        #expect(layout.canvasSize == image)
        #expect(layout.imageRect == CGRect(origin: .zero, size: image))
    }

    @Test func paddingGrowsTheCanvasAroundTheImage() {
        var frame = FrameStyle()
        frame.padding = 40
        let layout = CanvasLayout(imageSize: image, frame: frame)
        #expect(layout.canvasSize == CGSize(width: 1280, height: 880))
        #expect(layout.imageRect == CGRect(x: 40, y: 40, width: 1200, height: 800))
    }



}
