import AppKit
import ClearShotCore
import SwiftUI

/// The macOS Share menu (AirDrop, Messages, Mail, Slack, …).
enum ShareService {
    /// Kept while the menu is up; AppKit does not hold on to it.
    private static var picker: NSSharingServicePicker?

    /// Opens the Share menu right under `anchor` (a toolbar button or a card icon).
    static func share(_ items: [Any], from anchor: NSView) {
        let picker = NSSharingServicePicker(items: items)
        Self.picker = picker
        picker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
    }

    /// A PNG in the temp folder, named like a saved screenshot, for sharing something that is not on disk.
    /// Encodes off the main thread.
    static func temporaryPNG(_ image: CGImage, smaller: Bool, date: Date = .now) async throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "ClearShot", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: FileNamer.fileName(date: date, format: .png))
        try await Task.detached { try FileSaver.encode(image, format: .png, smaller: smaller).write(to: url, options: .atomic) }.value
        return url
    }
}

/// Remembers the AppKit view behind a SwiftUI button, so an AppKit menu can open under it.
final class AnchorHolder {
    weak var view: NSView?
}

/// Put in a button's `.background`: an empty view that is the same size as the button.
struct AnchorView: NSViewRepresentable {
    let holder: AnchorHolder

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        holder.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        holder.view = nsView
    }
}
