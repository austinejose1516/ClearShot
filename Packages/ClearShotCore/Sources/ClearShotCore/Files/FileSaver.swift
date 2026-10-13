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

    /// The file's bytes. Safe off the main thread; a Retina screen takes 50–150 ms. With `smaller`, a PNG is
    /// written with 256 colours when that looks the same and is smaller (Settings → Smaller PNG files).
    public static func encode(_ image: CGImage, format: ImageFormat, smaller: Bool) throws -> Data {
        let standard = try encode(image, format: format)
        guard smaller, format == .png, let small = smallerPNG(image, standard: standard) else { return standard }
        return small
    }

    /// The palette version of a PNG, or nil when it would lose too much (a photo) or would not be smaller.
    public static func smallerPNG(_ image: CGImage, standard: Data) -> Data? {
        guard let quantized = PaletteQuantizer.quantize(image), quantized.error <= PaletteQuantizer.maxError,
              let palette = PalettePNG.encode(quantized), palette.count < standard.count else { return nil }
        return palette
    }

    /// The file's bytes. Safe off the main thread; a Retina screen takes 50–150 ms.
    public static func encode(_ image: CGImage, format: ImageFormat) throws -> Data {
        let data = NSMutableData()
        let type: UTType = format == .png ? .png : .jpeg
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
            throw Failure.encodingFailed
        }
        let options: [CFString: Any] = format == .jpeg ? [kCGImageDestinationLossyCompressionQuality: 0.9] : [:]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure.encodingFailed }
        return data as Data
    }

    /// Replaces whatever is at `url` (the editor's Save).
    public static func overwrite(_ image: CGImage, format: ImageFormat, smaller: Bool = false, at url: URL) throws {
        try encode(image, format: format, smaller: smaller).write(to: url, options: .atomic)
    }
}
