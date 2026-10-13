import Foundation

/// Plain-text log at ~/Library/Logs/ClearShot.log. The unified log needs admin rights to read on this Mac; this does not.
public enum DiagnosticLog {
    public static let defaultFile = FileManager.default
        .homeDirectoryForCurrentUser
        .appending(path: "Library/Logs/ClearShot.log")

    public static let defaultMaxBytes = 2_000_000

    /// Appends a line; when the file is bigger than `maxBytes` it starts over.
    public static func write(_ message: String, to file: URL = defaultFile, maxBytes: Int = defaultMaxBytes) {
        let stamp = Date.now.formatted(.iso8601)
        let line = "\(stamp) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        let manager = FileManager.default
        try? manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let size = (try? manager.attributesOfItem(atPath: file.path(percentEncoded: false))[.size] as? Int) ?? 0
        if size > maxBytes {
            try? data.write(to: file)
            return
        }
        if let handle = try? FileHandle(forWritingTo: file) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: file)
        }
    }
}
