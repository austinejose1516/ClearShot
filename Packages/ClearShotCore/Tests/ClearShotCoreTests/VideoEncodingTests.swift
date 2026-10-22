import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct VideoEncodingTests {
    /// A 14" MacBook Pro screen: 1512 × 982 points at 2x.
    private let retinaPixels = CGSize(width: 3024, height: 1964)

    @Test func smallerAndBetterRecordAtOneX() {
        let smaller = VideoEncoding.settings(for: retinaPixels, scale: 2, quality: .smaller)
        #expect(smaller.width == 1512 && smaller.height == 982)
        let better = VideoEncoding.settings(for: retinaPixels, scale: 2, quality: .better)
        #expect(better.width == 1512 && better.height == 982)
    }

    @Test func retinaKeepsEveryPixel() {
        let retina = VideoEncoding.settings(for: retinaPixels, scale: 2, quality: .retina)
        #expect(retina.width == 3024 && retina.height == 1964)
    }

    @Test func sizesAreEvenBecauseH264WantsThat() {
        let odd = VideoEncoding.settings(for: CGSize(width: 1513, height: 983), scale: 1, quality: .retina)
        #expect(odd.width == 1512 && odd.height == 982)
        let oneX = VideoEncoding.settings(for: CGSize(width: 1001, height: 601), scale: 2, quality: .smaller)
        #expect(oneX.width == 500 && oneX.height == 300)
    }

    @Test func bitrateComesFromBitsPerPixelPerFrame() {
        let smaller = VideoEncoding.settings(for: retinaPixels, scale: 2, quality: .smaller)
        #expect(smaller.fps == 30)
        #expect(smaller.videoBitrate == 2_227_176)   // 1512 × 982 × 30 × 0.05
        let better = VideoEncoding.settings(for: retinaPixels, scale: 2, quality: .better)
        #expect(better.videoBitrate == 4_008_917)    // 1512 × 982 × 30 × 0.09, rounded
        #expect(smaller.audioBitrate == 96_000)
    }

    @Test func resizedKeepsSidesEvenAndScalesTheBitrate() {
        let base = VideoEncoding.Settings(width: 1000, height: 500, fps: 30, videoBitrate: 4_000_000, audioBitrate: 96_000)
        // 64 px of padding on each side, then one side made odd: both come out even.
        let framed = base.resized(to: CGSize(width: 1128, height: 629))
        #expect(framed.width == 1128 && framed.height == 628)
        #expect(framed.fps == 30 && framed.audioBitrate == 96_000)
        #expect(framed.videoBitrate == 5_667_072)   // 4_000_000 × (1128 × 628) / (1000 × 500)
        #expect(base.resized(to: CGSize(width: 1000, height: 500)) == base)
    }

    @Test func resizedClampsTheBitrate() {
        let big = VideoEncoding.Settings(width: 3000, height: 2000, fps: 30, videoBitrate: 18_000_000, audioBitrate: 96_000)
        #expect(big.resized(to: CGSize(width: 3480, height: 2480)).videoBitrate == VideoEncoding.maximumVideoBitrate)
        let small = VideoEncoding.Settings(width: 400, height: 300, fps: 30, videoBitrate: 1_000_000, audioBitrate: 96_000)
        #expect(small.resized(to: CGSize(width: 200, height: 150)).videoBitrate == VideoEncoding.minimumVideoBitrate)
    }

    @Test func bitrateIsClampedToASaneRange() {
        let tiny = VideoEncoding.settings(for: CGSize(width: 200, height: 100), scale: 1, quality: .smaller)
        #expect(tiny.videoBitrate == 1_000_000)
        let huge = VideoEncoding.settings(for: CGSize(width: 6016, height: 3384), scale: 2, quality: .retina)
        #expect(huge.videoBitrate == 20_000_000)
    }

    @Test func estimateIsTheUpperBoundForTheLength() {
        let settings = VideoEncoding.settings(for: retinaPixels, scale: 2, quality: .smaller)
        #expect(settings.estimatedBytes(seconds: 60) == 17_423_820)   // (2 227 176 + 96 000) × 60 / 8
        #expect(settings.estimatedBytes(seconds: 0) == 0)
    }

    @Test func qualitiesHaveTitlesForTheSettingsPicker() {
        #expect(VideoQuality.allCases.map(\.title) == ["Smaller", "Better", "Retina"])
        #expect(VideoQuality(rawValue: "smaller") == .smaller)
    }
}
