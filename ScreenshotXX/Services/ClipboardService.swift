import AppKit

enum ClipboardService {
    /// Puts the image on the general pasteboard as TIFF (what NSImage writes) plus PNG (what Slack and browsers prefer).
    static func copy(_ image: CGImage) {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
        if let tiff = nsImage.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            pasteboard.setData(png, forType: .png)
        }
    }
}
