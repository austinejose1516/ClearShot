import AppKit
import ClearShotCore
import SwiftUI

struct BackgroundView: View {
    let background: Background

    var body: some View {
        switch background {
        case .none:
            Color.clear
        case .solid(let color):
            Color(color)
        case .gradient(let preset):
            LinearGradient(colors: [Color(preset.start), Color(preset.end)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .image(let url):
            if let image = BackgroundImageCache.image(at: url) {
                GeometryReader { proxy in
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
            } else {
                Color.gray
            }
        }
    }
}

enum BackgroundImageCache {
    private static var images: [URL: NSImage] = [:]

    static func image(at url: URL) -> NSImage? {
        if let cached = images[url] { return cached }
        guard let loaded = NSImage(contentsOf: url) else { return nil }
        images[url] = loaded
        return loaded
    }
}
