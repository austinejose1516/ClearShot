import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct FrameProfileTests {
    @Test func oneRowOfSamplesPerImageRowAndTheSameImageGivesTheSameProfile() {
        let profile = FrameProfile.of(rowImage([10, 20, 30]))
        #expect(profile.height == 3)
        #expect(profile.width == 8)   // narrower than the sample count: one sample per pixel
        #expect(profile.rowDistance(0, to: profile, 1) == 10)
        #expect(profile.rowDistance(0, to: profile, 2) == 20)
        #expect(profile == FrameProfile.of(rowImage([10, 20, 30])))
    }

    @Test func aWideImageIsShrunkToTheSampleCountAndItsRowsStayApart() {
        let profile = FrameProfile.of(rowImage([10, 20, 30], width: 1000))
        #expect(profile.width == FrameProfile.samplesPerRow)
        #expect(profile.samples.count == 3 * FrameProfile.samplesPerRow)
        #expect(profile.rowDistance(0, to: profile, 0) == 0)
        #expect(profile.rowDistance(0, to: profile, 2) == 20)
    }

    @Test func theDistanceBetweenFramesIsTheMeanDifferenceOfAllSamples() {
        let a = FrameProfile.of(rowImage([0, 0]))
        let b = FrameProfile.of(rowImage([10, 30]))
        #expect(a.distance(to: b) == 20)
        #expect(a.distance(to: a) == 0)
    }

    @Test func theRightEdgeCanBeLeftOutForTheScrollbar() {
        // Rows differ only in the rightmost 4 pixels (a scrollbar thumb that moved).
        let plain = greyImage(width: 32, height: 2) { _, _ in 50 }
        let withThumb = greyImage(width: 32, height: 2) { x, y in x >= 28 && y == 0 ? 200 : 50 }
        #expect(FrameProfile.of(plain) != FrameProfile.of(withThumb))
        #expect(FrameProfile.of(plain, ignoringRightPixels: 4) == FrameProfile.of(withThumb, ignoringRightPixels: 4))
    }

    @Test func onlyTheGivenColumnsCount() {
        // A sidebar in columns 0..<16 with a different grey per row; the same grey everywhere else.
        let image = greyImage(width: 64, height: 3) { x, y in x < 16 ? UInt8(50 * y) : 90 }
        let whole = FrameProfile.of(image)
        let band = FrameProfile.of(image, columns: 16..<64)
        #expect(whole.rowDistance(0, to: whole, 2) > 0)
        #expect(band.rowDistance(0, to: band, 2) == 0)
        #expect(band.width == 48)
    }
}
