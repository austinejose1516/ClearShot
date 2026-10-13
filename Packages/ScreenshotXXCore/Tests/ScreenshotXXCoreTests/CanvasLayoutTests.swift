import CoreGraphics
import Testing
@testable import ScreenshotXXCore

@Suite struct CanvasLayoutTests {
    private let image = CGSize(width: 1200, height: 800)

    @Test func noFrameMeansCanvasEqualsImage() {
        let layout = CanvasLayout(imageSize: image, frame: FrameStyle())
        #expect(layout.canvasSize == image)
        #expect(layout.imageRect == CGRect(origin: .zero, size: image))
        #expect(layout.imageScale == 1)
    }

    @Test func paddingGrowsTheCanvasAroundTheImage() {
        var frame = FrameStyle()
        frame.padding = 40
        let layout = CanvasLayout(imageSize: image, frame: frame)
        #expect(layout.canvasSize == CGSize(width: 1280, height: 880))
        #expect(layout.imageRect == CGRect(x: 40, y: 40, width: 1200, height: 800))
    }

    @Test func insetShrinksTheImageInsideTheSameCanvas() {
        var frame = FrameStyle()
        frame.inset = 20
        let layout = CanvasLayout(imageSize: image, frame: frame)
        #expect(layout.canvasSize == image)
        #expect(layout.imageRect == CGRect(x: 20, y: 20, width: 1160, height: 760))
        #expect(abs(layout.imageScale - 1160.0 / 1200.0) < 0.0001)
        #expect(layout.imageToCanvas(CGPoint(x: 0, y: 0)) == CGPoint(x: 20, y: 20))
        let back = layout.canvasToImage(layout.imageToCanvas(CGPoint(x: 600, y: 400)))
        #expect(abs(back.x - 600) < 0.001 && abs(back.y - 400) < 0.001)
    }


}
