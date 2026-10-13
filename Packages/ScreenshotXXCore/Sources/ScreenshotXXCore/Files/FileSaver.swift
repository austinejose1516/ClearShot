import CoreGraphics
import Foundation
import ImageIO

import UniformTypeIdentifiers

public enum FileSaver {
    public enum Failure: LocalizedError {
        case encodingFailed(URL)

        public var errorDescription: String? {
            switch self {
            case .encodingFailed(let url): "Could not write the image to \(url.path(percentEncoded: false))."
            }
        }
    }

    /// Creates the folder if needed. Never overwrites: a clash gets " (2)", " (3)", …
    public static func save(_ image: CGImage, format: ImageFormat, to folder: URL, date: Date = .now) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = FileNamer.uniqueFileName(FileNamer.fileName(date: date, format: format)) { candidate in
            fileManager.fileExists(atPath: folder.appending(path: candidate).path(percentEncoded: false))
        }
        let url = folder.appending(path: name)
        let type: UTType = format == .png ? .png : .jpeg
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw Failure.encodingFailed(url)
        }
        let options: [CFString: Any] = format == .jpeg ? [kCGImageDestinationLossyCompressionQuality: 0.9] : [:]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure.encodingFailed(url) }
        return url
    }
}
