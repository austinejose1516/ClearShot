import AppKit
import ClearShotCore

/// The shared tail of Upload (editor and card): send the bytes, put the link on the clipboard, say so.
enum UploadService {
    /// Images go to the bucket's "images/" folder (scrolling shots are images too); videos go to "videos/".
    /// Returns the link, so the card can offer it again.
    @discardableResult
    static func upload(_ data: Data, format: ImageFormat, with uploader: R2Uploader,
                       progress: (@Sendable (Double) -> Void)? = nil) async throws -> URL {
        let key = R2Folder.images.key(for: R2Name.random(format: format))
        let link = try await uploader.upload(data, contentType: format.mimeType, key: key, progress: progress)
        copy(link)
        DiagnosticLog.write("uploaded \(data.count) bytes, link copied: \(link.absoluteString)")
        Toast.show("Link copied")
        return link
    }

    /// A file on disk (a recording) goes to its own folder: "videos/k3x9p2m7qa.mp4".
    @discardableResult
    static func upload(fileURL: URL, contentType: String, folder: R2Folder, with uploader: R2Uploader,
                       progress: (@Sendable (Double) -> Void)? = nil) async throws -> URL {
        let key = folder.key(for: R2Name.random(fileExtension: fileURL.pathExtension))
        let link = try await uploader.upload(file: fileURL, contentType: contentType, key: key, progress: progress)
        copy(link)
        DiagnosticLog.write("uploaded \(fileURL.lastPathComponent), link copied: \(link.absoluteString)")
        Toast.show("Link copied")
        return link
    }

    static func copy(_ link: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(link.absoluteString, forType: .string)
    }

    /// Upload without a cloud setup: show where to do it.
    static func openCloudSettings() {
        (NSApp.delegate as? AppDelegate)?.showSettings(tab: .cloud)
    }
}
