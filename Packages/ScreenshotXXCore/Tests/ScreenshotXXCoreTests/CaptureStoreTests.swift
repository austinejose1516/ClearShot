import CoreGraphics
import Foundation
import Testing
@testable import ScreenshotXXCore

@Suite struct CaptureStoreTests {
    private func pixel() -> CGImage {
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    @Test func addKeepsNewestFirstAndRespectsLimit() {
        let store = CaptureStore(limit: 2)
        let first = Capture(kind: .fullScreen, image: pixel())
        let second = Capture(kind: .fullScreen, image: pixel())
        let third = Capture(kind: .fullScreen, image: pixel())
        store.add(first); store.add(second); store.add(third)
        #expect(store.captures.map(\.id) == [third.id, second.id])
    }

    @Test func removeDropsOnlyThatCapture() {
        let store = CaptureStore()
        let a = Capture(kind: .area, image: pixel())
        let b = Capture(kind: .area, image: pixel())
        store.add(a); store.add(b)
        store.remove(id: a.id)
        #expect(store.captures.map(\.id) == [b.id])
    }

    @Test func updateReplacesTheStoredCopy() {
        let store = CaptureStore()
        var a = Capture(kind: .window, image: pixel())
        store.add(a)
        a.fileURL = URL(filePath: "/tmp/a.png")
        store.update(a)
        #expect(store.capture(id: a.id)?.fileURL?.path() == "/tmp/a.png")
    }
}
