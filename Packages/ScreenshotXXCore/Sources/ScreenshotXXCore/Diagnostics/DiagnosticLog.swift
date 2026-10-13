import Foundation

/// Plain-text log at ~/Library/Logs/ScreenshotXX.log. The unified log needs admin rights to read on this Mac; this does not.
public enum DiagnosticLog {
    public static let defaultFile = FileManager.default
        .homeDirectoryForCurrentUser
        .appending(path: "Library/Logs/ScreenshotXX.log")

    public static func write(_ message: String, to file: URL = defaultFile) {
        let stamp = ISO8601DateFormatter().string(from: .now)
        let line = "\(stamp) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        let manager = FileManager.default
        try? manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: file) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: file)
        }
    }
}
