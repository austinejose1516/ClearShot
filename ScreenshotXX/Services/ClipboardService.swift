import AppKit
import ScreenshotXXCore

enum ClipboardService {
    /// Encodes right away; fine for a button press (Copy on the card or in the editor).
    static func copy(_ image: CGImage) {
        guard let png = try? FileSaver.encode(image, format: .png) else { return }
        copy(png: png, of: image)
    }

    /// Puts ready PNG bytes on the general pasteboard (what Slack and browsers read).
    /// TIFF, for older apps, is only made if an app asks for it, so copying stays fast.
    static func copy(png: Data, of image: CGImage) {
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        item.setDataProvider(TIFFProvider(image: image), forTypes: [.tiff])
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }
}

/// Makes the TIFF only when an app pastes it. AppKit calls this off the main actor.
nonisolated private final class TIFFProvider: NSObject, NSPasteboardItemDataProvider, Sendable {
    private let image: CGImage

    init(image: CGImage) {
        self.image = image
    }

    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        if let tiff = NSBitmapImageRep(cgImage: image).tiffRepresentation {
            item.setData(tiff, forType: type)
        }
    }
}
