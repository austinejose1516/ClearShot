import ClearShotCore
import Foundation

/// Where recordings live until they are saved. The system clears the temp folder on its own; this sweeps what
/// is older than a day in case the app was quit mid-way.
enum TemporaryFiles {
    static let recordingsFolder = FileManager.default.temporaryDirectory
        .appending(path: "ClearShot/Recordings", directoryHint: .isDirectory)

    /// A fresh file name for a recording, in the recordings folder (created if needed).
    static func newRecordingURL(date: Date = .now) throws -> URL {
        try FileManager.default.createDirectory(at: recordingsFolder, withIntermediateDirectories: true)
        return recordingsFolder.appending(path: FileNamer.fileName(date: date, fileExtension: "mp4"))
    }

    static func sweepRecordings(olderThan age: TimeInterval = 24 * 60 * 60, now: Date = .now) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: recordingsFolder, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for file in files {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? now
            guard now.timeIntervalSince(modified) > age else { continue }
            try? fileManager.removeItem(at: file)
            DiagnosticLog.write("removed old temp recording \(file.lastPathComponent)")
        }
    }
}
