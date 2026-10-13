import CoreGraphics
import Foundation
import ImageIO

import UniformTypeIdentifiers

public enum FileSaver {
    public enum Failure: LocalizedError {
        case encodingFailed

        public var errorDescription: String? {
            switch self {
            case .encodingFailed: "Could not encode the image."
            }
        }
    }

    /// Picks the file name for a new capture and creates the folder if needed. Writes nothing yet,
    /// so the card can show right away. Never overwrites: a clash gets " (2)", " (3)", …
    public static func reserveURL(for format: ImageFormat, in folder: URL, date: Date = .now) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = FileNamer.uniqueFileName(FileNamer.fileName(date: date, format: format)) { candidate in
            fileManager.fileExists(atPath: folder.appending(path: candidate).path(percentEncoded: false))
        }
        return folder.appending(path: name)
    }

    /// What `encode(_:preferring:budget:)` made: the bytes and the format they are in (the file needs the
    /// matching extension).
    public struct EncodedImage: Sendable {
        public let data: Data
        public let format: ImageFormat
        /// The ordinary PNG, when one was made on the way; the clipboard wants that one.
        public let standardPNG: Data?
    }

    /// The file in the preferred format, or, with a size `budget` in bytes (Settings → Keep files under 1 MB):
    /// a PNG becomes a 256-colour PNG when that looks the same, and whatever is still over the budget (a photo
    /// in the picture) becomes a JPEG, its quality stepped down until it fits. Safe off the main thread.
    public static func encode(_ image: CGImage, preferring format: ImageFormat, budget: Int?) throws -> EncodedImage {
        let standard = try encode(image, format: format)
        let standardPNG = format == .png ? standard : nil
        guard let budget else { return EncodedImage(data: standard, format: format, standardPNG: standardPNG) }
        var best = standard
        if format == .png, let palette = smallerPNG(image, standard: standard) { best = palette }
        if best.count <= budget { return EncodedImage(data: best, format: format, standardPNG: standardPNG) }
        let jpeg = try jpeg(image, within: budget)
        guard jpeg.count < best.count else { return EncodedImage(data: best, format: format, standardPNG: standardPNG) }
        return EncodedImage(data: jpeg, format: .jpeg, standardPNG: standardPNG)
    }

    /// The palette version of a PNG, or nil when it would lose too much (a photo) or would not be smaller.
    public static func smallerPNG(_ image: CGImage, standard: Data) -> Data? {
        guard let quantized = PaletteQuantizer.quantize(image), quantized.error <= PaletteQuantizer.maxError,
              let palette = PalettePNG.encode(quantized), palette.count < standard.count else { return nil }
        return palette
    }

    /// Qualities tried in turn for a JPEG that must fit a budget; text still reads cleanly at the last one.
    public static let budgetQualities: [Double] = [0.85, 0.75, 0.65, 0.55]

    /// The JPEG at the highest of those qualities that fits, or the smallest one when none does.
    public static func jpeg(_ image: CGImage, within budget: Int) throws -> Data {
        var smallest = Data()
        for quality in budgetQualities {
            let data = try encode(image, format: .jpeg, quality: quality)
            if data.count <= budget { return data }
            if smallest.isEmpty || data.count < smallest.count { smallest = data }
        }
        return smallest
    }

    /// The file's bytes. Safe off the main thread; a Retina screen takes 50–150 ms. `quality` is for JPEG.
    public static func encode(_ image: CGImage, format: ImageFormat, quality: Double = 0.9) throws -> Data {
        let data = NSMutableData()
        let type: UTType = format == .png ? .png : .jpeg
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
            throw Failure.encodingFailed
        }
        let options: [CFString: Any] = format == .jpeg ? [kCGImageDestinationLossyCompressionQuality: quality] : [:]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure.encodingFailed }
        return data as Data
    }
}
