import ScreenshotXXCore
import SwiftUI

/// The card: thumbnail you can drag out, size caption, and Edit / Copy / Reveal / Close.
struct QuickAccessView: View {
    let capture: Capture
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onReveal: () -> Void
    let onClose: () -> Void
    let onHoverChange: (Bool) -> Void

    @State private var copied = false

    var body: some View {
        VStack(spacing: 8) {
            thumbnail
            Text("\(capture.image.width) × \(capture.image.height)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                tool("Edit", "pencil", action: onEdit)
                tool(copied ? "Copied" : "Copy", copied ? "checkmark" : "doc.on.doc") {
                    onCopy()
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.2))
                        copied = false
                    }
                }
                tool("Reveal in Finder", "folder", action: onReveal)
                    .disabled(capture.fileURL == nil)
                Spacer()
                tool("Close", "xmark", action: onClose)
            }
        }
        .padding(10)
        .frame(width: QuickAccessLayout.cardSize.width, height: QuickAccessLayout.cardSize.height)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .onHover(perform: onHoverChange)
    }

    private var thumbnail: some View {
        Image(decorative: capture.image, scale: 1)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: 132)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.25)))
            .onDrag {
                capture.fileURL.flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider()
            }
            .help(capture.fileURL?.lastPathComponent ?? "Not saved to disk")
    }

    private func tool(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.borderless)
        .help(title)
    }
}
