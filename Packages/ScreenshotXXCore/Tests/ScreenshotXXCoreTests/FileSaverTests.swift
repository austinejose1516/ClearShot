import ImageIO
import CoreGraphics
import Foundation
import Testing
@testable import ScreenshotXXCore

private func image(side: Int) -> CGImage {
    let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    return context.makeImage()!
}

private func tempFolder() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "saver-\(UUID().uuidString)/nested", directoryHint: .isDirectory)
}

@Suite struct FileSaverTests {
    @Test func reservingCreatesTheFolderButNoFile() throws {
        let folder = tempFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let url = try FileSaver.reserveURL(for: .png, in: folder, date: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(url.pathExtension == "png")
        #expect(url.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL)
        #expect(FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)))
        #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    }

    @Test func aTakenNameGetsANumber() throws {
        let folder = tempFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let first = try FileSaver.reserveURL(for: .png, in: folder, date: date)
        try FileSaver.encode(image(side: 2), format: .png).write(to: first)
        let second = try FileSaver.reserveURL(for: .png, in: folder, date: date)
        #expect(second != first)
        #expect(second.lastPathComponent.hasSuffix(" (2).png"))
    }

    @Test(arguments: [ImageFormat.png, .jpeg])
    func encodedDataDecodesToTheSameSize(format: ImageFormat) throws {
        let data = try FileSaver.encode(image(side: 3), format: format)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let reloaded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(reloaded.width == 3)
        #expect(CGImageSourceGetType(source) as String? == (format == .png ? "public.png" : "public.jpeg"))
    }

    @Test func overwriteReplacesTheFileInPlace() throws {
        let folder = tempFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let url = try FileSaver.reserveURL(for: .png, in: folder)
        try FileSaver.encode(image(side: 2), format: .png).write(to: url)
        try FileSaver.overwrite(image(side: 3), format: .png, at: url)
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let reloaded = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        #expect(reloaded.width == 3)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).count == 1)
    }
}
