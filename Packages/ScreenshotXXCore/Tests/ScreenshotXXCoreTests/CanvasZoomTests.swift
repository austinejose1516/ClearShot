import CoreGraphics
import Testing
@testable import ScreenshotXXCore

@Suite struct CanvasZoomTests {
    private func zoom(canvas: CGSize = CGSize(width: 2000, height: 1000),
                      viewport: CGSize = CGSize(width: 1048, height: 1048)) -> CanvasZoom {
        var zoom = CanvasZoom()
        zoom.canvasSize = canvas
        zoom.viewportSize = viewport
        return zoom
    }

    @Test func fitShowsTheWholeCanvasWithAMarginAndNeverEnlarges() {
        #expect(zoom().scale == 0.5)                                                   // (1048 − 48) / 2000
        #expect(zoom(canvas: CGSize(width: 100, height: 100)).scale == 1)             // small images stay at 100 %
        #expect(CanvasZoom().scale == 1)                                               // nothing laid out yet
    }

    @Test func fitFollowsTheViewportButAFixedScaleDoesNot() {
        var fit = zoom()
        var fixed = zoom()
        fixed.set(scale: 1)
        fit.viewportSize = CGSize(width: 548, height: 548)
        fixed.viewportSize = CGSize(width: 548, height: 548)
        #expect(fit.scale == 0.25)
        #expect(fixed.scale == 1)
        #expect(!fixed.isFit)
    }

    @Test func choosingFitAgainUsesTheCurrentViewport() {
        var zoom = zoom()
        zoom.set(scale: 2)
        zoom.mode = .fit
        #expect(zoom.scale == 0.5)
        #expect(zoom.isFit)
    }

    @Test func zoomStepsFromTheShownScaleAndClamps() {
        var zoom = zoom()
        zoom.zoom(by: CanvasZoom.step)
        #expect(zoom.scale == 0.625)
        for _ in 0..<20 { zoom.zoom(by: CanvasZoom.step) }
        #expect(zoom.scale == CanvasZoom.range.upperBound)
        for _ in 0..<40 { zoom.zoom(by: 1 / CanvasZoom.step) }
        #expect(zoom.scale == CanvasZoom.range.lowerBound)
    }

    @Test func labelIsAWholePercent() {
        var zoom = zoom()
        #expect(zoom.label == "50 %")
        zoom.set(scale: 1.234)
        #expect(zoom.label == "123 %")
    }
}
