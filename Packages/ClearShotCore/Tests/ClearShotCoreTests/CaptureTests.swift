import CoreGraphics
import Foundation
import Testing
@testable import ClearShotCore

@Suite struct CaptureTests {
    @Test func aScrollingShotKnowsHowManyPagesItIs() {
        let scrolling = Capture(kind: .scrolling, image: blankImage(), pageCount: 3)
        #expect(scrolling.kind == .scrolling)
        #expect(scrolling.pageCount == 3)
        #expect(Capture(kind: .area, image: blankImage()).pageCount == 1)
    }

    @Test func aRecordingCarriesItsLengthAndEncoding() {
        let encoding = VideoEncoding.settings(for: CGSize(width: 1600, height: 1000), scale: 2, quality: .smaller)
        let recording = Capture(kind: .area, image: blankImage(), video: Capture.Video(duration: 42, encoding: encoding))
        #expect(recording.isVideo)
        #expect(recording.video?.duration == 42)
        #expect(recording.video?.encoding == encoding)
        #expect(Capture(kind: .area, image: blankImage()).isVideo == false)
    }

    @Test func anEditedPictureKeepsTheSameCardAndFile() {
        let url = URL(filePath: "/tmp/ClearShot.png")
        var capture = Capture(kind: .window, image: blankImage(), windowImage: blankImage(), fileURL: url)
        let id = capture.id
        let edited = blankImage()
        capture.edited(image: edited)
        #expect(capture.id == id)
        #expect(capture.image === edited)
        #expect(capture.fileURL == url)
        // The edited picture (frame and all) is the new starting point, not the bare window.
        #expect(capture.windowImage == nil)
        #expect(capture.editorImage === edited)
    }

    @Test func savingATrimmedVideoUpdatesItsLengthAndPicture() {
        let encoding = VideoEncoding.settings(for: CGSize(width: 1600, height: 1000), scale: 2, quality: .smaller)
        var capture = Capture(kind: .area, image: blankImage(), video: Capture.Video(duration: 42, encoding: encoding))
        let poster = blankImage()
        capture.saved(videoDuration: 12.5, poster: poster, at: URL(filePath: "/tmp/ClearShot.mp4"))
        #expect(capture.video == Capture.Video(duration: 12.5, encoding: encoding))
        #expect(capture.image === poster)
        #expect(capture.fileURL?.lastPathComponent == "ClearShot.mp4")
    }

    @Test func savingAVideoCanChangeItsSize() {
        let encoding = VideoEncoding.settings(for: CGSize(width: 1000, height: 500), scale: 1, quality: .smaller)
        var capture = Capture(kind: .area, image: blankImage(), video: Capture.Video(duration: 3, encoding: encoding))
        let framed = encoding.resized(to: CGSize(width: 1128, height: 628))
        capture.saved(videoDuration: 3, poster: blankImage(), encoding: framed, at: URL(filePath: "/tmp/ClearShot.mp4"))
        #expect(capture.video?.encoding == framed)
        capture.saved(videoDuration: 2, poster: blankImage(), at: URL(filePath: "/tmp/ClearShot.mp4"))
        #expect(capture.video?.encoding == framed && capture.video?.duration == 2)
    }

    @Test func scrollingIsOneOfTheKinds() {
        #expect(CaptureKind.allCases.contains(.scrolling))
        #expect(CaptureKind.scrolling.rawValue == "scrolling")
    }
}
