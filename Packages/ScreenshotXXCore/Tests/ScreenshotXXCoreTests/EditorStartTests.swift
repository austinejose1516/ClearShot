import CoreGraphics
import Testing
@testable import ScreenshotXXCore

/// What the editor opens for each kind of capture.
@Suite struct EditorStartTests {
    private func image(_ width: Int, _ height: Int) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    @Test func anAreaCaptureOpensAsIsWithAPlainFrame() {
        let capture = Capture(kind: .area, image: image(100, 60))
        #expect(capture.editorImage === capture.image)
        #expect(capture.editorFrame == FrameStyle())
    }

    @Test func aWindowCaptureOpensTheWindowAloneWithTheShadowMarginAsPadding() {
        let capture = Capture(kind: .window, image: image(140, 100), windowImage: image(100, 60))
        #expect(capture.editorImage === capture.windowImage)
        #expect(capture.editorFrame.padding == 20)
        #expect(capture.editorFrame.shadow > 0)
        #expect(capture.editorFrame.background == .none)
    }

    @Test func theWindowFrameShadowStaysInsideTheMargin() {
        let frame = FrameStyle.windowShadow(margin: 112, imageSize: CGSize(width: 1600, height: 1000))
        let radius = frame.shadowRadius(canvasSize: CGSize(width: 1824, height: 1224))
        #expect(abs(radius - 112 / 3) < 0.5)
        #expect(frame.shadow > 0 && frame.shadow <= 100)
        // A huge margin on a tiny image cannot push the slider past its end.
        #expect(FrameStyle.windowShadow(margin: 500, imageSize: CGSize(width: 10, height: 10)).shadow == 100)
    }

    @Test func shadowGeometryFollowsTheSlider() {
        var frame = FrameStyle()
        #expect(frame.shadowRadius(canvasSize: CGSize(width: 1000, height: 500)) == 0)
        #expect(frame.shadowOpacity == 0)
        frame.shadow = 100
        #expect(frame.shadowRadius(canvasSize: CGSize(width: 1000, height: 500)) == 50)   // 10 % of the short side
        #expect(abs(frame.shadowOpacity - 0.6) < 0.0001)
    }

    @Test func aDocumentStartsWithTheGivenFrameAndNothingToUndo() {
        var frame = FrameStyle()
        frame.padding = 20
        let document = EditorDocument(baseImage: image(10, 10), frame: frame)
        #expect(document.frame == frame)
        #expect(document.initialFrame == frame)
        #expect(!document.canUndo)
        #expect(document.layout.canvasSize == CGSize(width: 50, height: 50))
    }
}
