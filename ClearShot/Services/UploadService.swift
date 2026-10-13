import AppKit
import ClearShotCore

/// The shared tail of Upload (editor and card): send the bytes, put the link on the clipboard, say so.
enum UploadService {
    /// Images go to the bucket's "images/" folder; videos and scrolling shots get their own folders later.
    static func upload(_ data: Data, format: ImageFormat, with uploader: R2Uploader) async throws {
        let key = R2Folder.images.key(for: R2Name.random(format: format))
        let link = try await uploader.upload(data, contentType: format.mimeType, key: key)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(link.absoluteString, forType: .string)
        DiagnosticLog.write("uploaded \(data.count) bytes, link copied: \(link.absoluteString)")
        Toast.show("Link copied")
    }

    /// Upload without a cloud setup: show where to do it.
    static func openCloudSettings() {
        (NSApp.delegate as? AppDelegate)?.showSettings(tab: .cloud)
    }
}
