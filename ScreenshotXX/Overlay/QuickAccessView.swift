import Observation
import ScreenshotXXCore
import SwiftUI

/// Lets the controller play the exit animation before the panel goes away.
@Observable
final class CardPresentation {
    var isDismissing = false
}

/// The card: thumbnail you can drag out, size caption, and Edit / Copy / Reveal / Close.
struct QuickAccessView: View {
    let capture: Capture
    let presentation: CardPresentation
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void
    let onHoverChange: (Bool) -> Void

    @State private var copied = false
    @State private var appeared = false
    @State private var hovered = false

    var body: some View {
        let dismissing = presentation.isDismissing
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
                tool("Move to Trash", "trash", action: onDelete)
                    .disabled(capture.fileURL == nil)
                tool("Close", "xmark", action: onClose)
            }
        }
        .padding(10)
        .frame(width: QuickAccessLayout.cardSize.width, height: QuickAccessLayout.cardSize.height)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .scaleEffect(dismissing ? 0.88 : (appeared ? (hovered ? 1.03 : 1) : 0.8))
        .opacity(dismissing ? 0 : (appeared ? 1 : 0))
        .offset(y: dismissing ? 18 : (appeared ? 0 : 36))
        .padding(QuickAccessLayout.panelMargin)
        .animation(.spring(response: 0.42, dampingFraction: 0.72), value: appeared)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hovered)
        .animation(.easeIn(duration: 0.22), value: dismissing)
        .onAppear { appeared = true }
        .onHover { inside in
            hovered = inside
            onHoverChange(inside)
        }
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
