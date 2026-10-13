import ImageIO
import CoreGraphics
import Foundation
import Testing
@testable import ScreenshotXXCore

@Suite struct FileSaverTests {
    private func pixel() -> CGImage {
        let context = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    private func tempFolder() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "saver-\(UUID().uuidString)/nested", directoryHint: .isDirectory)
    }

    @Test func createsMissingFolderAndWritesPNG() throws {
        let folder = tempFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let url = try FileSaver.save(pixel(), format: .png, to: folder, date: Date(timeIntervalSince1970: 1_800_000_000))
        let size = try FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))[.size] as? Int ?? 0
        #expect(url.pathExtension == "png")
        #expect(size > 0)
    }

    @Test func sameSecondCapturesGetDistinctFiles() throws {
        let folder = tempFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let first = try FileSaver.save(pixel(), format: .png, to: folder, date: date)
        let second = try FileSaver.save(pixel(), format: .png, to: folder, date: date)
        #expect(first != second)
        #expect(second.lastPathComponent.hasSuffix(" (2).png"))
        #expect(FileManager.default.fileExists(atPath: first.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: second.path(percentEncoded: false)))
    }
}

@Suite struct FileSaverOverwriteTests {
    private func image(side: Int) -> CGImage {
        let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    @Test func overwriteReplacesTheFileInPlace() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "ow-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try FileSaver.save(image(side: 2), format: .png, to: folder)
        try FileSaver.overwrite(image(side: 3), format: .png, at: url)
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let reloaded = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        #expect(reloaded.width == 3)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).count == 1)
    }
}
