import Foundation

public enum FileNamer {
    /// "ClearShot 2026-10-13 at 09.41.12.png" — same shape as macOS's own screenshots.
    public static func fileName(date: Date, format: ImageFormat, timeZone: TimeZone = .current) -> String {
        fileName(date: date, fileExtension: format.fileExtension, timeZone: timeZone)
    }

    /// The same name for any kind of file ("mp4" for a recording).
    public static func fileName(date: Date, fileExtension: String, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "ClearShot \(formatter.string(from: date)).\(fileExtension)"
    }

    /// Adds " (2)", " (3)", … before the extension until `exists` says the name is free.
    public static func uniqueFileName(_ name: String, exists: (String) -> Bool) -> String {
        guard exists(name) else { return name }
        let url = URL(filePath: name)
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var counter = 2
        while true {
            let candidate = "\(stem) (\(counter)).\(ext)"
            if !exists(candidate) { return candidate }
            counter += 1
        }
    }
}
