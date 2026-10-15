import ImageIO
import CoreGraphics
import Foundation
import Testing
@testable import ClearShotCore

private func image(side: Int) -> CGImage {
    let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    return context.makeImage()!
}

/// Random colours: too many for a palette, so only a JPEG gets it under a small budget.
private func noise(width: Int, height: Int) -> CGImage {
    var state: UInt64 = 7
    var bytes = [UInt8](repeating: 255, count: width * height * 4)
    for index in bytes.indices where index % 4 != 3 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        bytes[index] = UInt8(truncatingIfNeeded: state >> 33)
    }
    let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
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

    @Test func aVideoReservesAnMP4Name() throws {
        let folder = tempFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let url = try FileSaver.reserveURL(fileExtension: "mp4", in: folder, date: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(url.pathExtension == "mp4")
        #expect(url.lastPathComponent.hasPrefix("ClearShot "))
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

    @Test func overwritingKeepsTheFileAndItsFormat() throws {
        let folder = tempFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let url = try FileSaver.reserveURL(for: .png, in: folder)
        try FileSaver.encode(image(side: 2), format: .png).write(to: url)
        let written = try FileSaver.overwrite(url, with: image(side: 3), budget: nil)
        #expect(written == url)
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        #expect(CGImageSourceCreateImageAtIndex(source, 0, nil)!.width == 3)
    }

    @Test func overwritingOverTheBudgetTurnsThePNGIntoAJPG() throws {
        let folder = tempFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let url = try FileSaver.reserveURL(for: .png, in: folder)
        try FileSaver.encode(image(side: 2), format: .png).write(to: url)
        let written = try FileSaver.overwrite(url, with: noise(width: 200, height: 150), budget: 1)
        #expect(written.pathExtension == "jpg")
        #expect(written.deletingPathExtension() == url.deletingPathExtension())
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
        #expect(files == [written.lastPathComponent])
    }

    @Test func writingAgainReplacesTheFileInPlace() throws {
        let folder = tempFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let url = try FileSaver.reserveURL(for: .png, in: folder)
        try FileSaver.encode(image(side: 2), format: .png).write(to: url)
        try FileSaver.encode(image(side: 3), preferring: .png, budget: nil).data.write(to: url, options: .atomic)
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let reloaded = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        #expect(reloaded.width == 3)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).count == 1)
    }
}
