import Observation
import ScreenshotXXCore
import SwiftUI

/// Lets the controller play the exit animation before the panel goes away.
@Observable
final class CardPresentation {
    var isDismissing = false
}

/// The card: the screenshot fills it; on hover a glass bar slides up with the actions, plus close and size on top.
struct QuickAccessView: View {
    let capture: Capture
    let presentation: CardPresentation
    let onEdit: () -> Void
    let onCopy: () -> Void
    /// Gets the Share icon's AppKit view, so the Share menu can open under it.
    let onShare: (NSView?) -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void
    let onHoverChange: (Bool) -> Void

    @State private var copied = false
    @State private var appeared = false
    @State private var hovered = false
    @State private var shareAnchor = AnchorHolder()

    var body: some View {
        let dismissing = presentation.isDismissing
        let size = QuickAccessLayout.cardSize
        ZStack {
            thumbnail
            if hovered {
                VStack(spacing: 0) {
                    HStack {
                        CircleButton(symbol: "xmark", help: "Close", action: onClose)
                        Spacer()
                        Text("\(capture.image.width) × \(capture.image.height)")
                            .font(.caption2.monospacedDigit().weight(.medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .glassEffect(.regular, in: .capsule)
                    }
                    Spacer(minLength: 0)
                    actionBar
                }
                .padding(8)
                .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .frame(width: size.width, height: size.height)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.18)))
        .scaleEffect(dismissing ? 0.88 : (appeared ? (hovered ? 1.03 : 1) : 0.8))
        .opacity(dismissing ? 0 : (appeared ? 1 : 0))
        .offset(y: dismissing ? 18 : (appeared ? 0 : 36))
        .padding(QuickAccessLayout.panelMargin)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: appeared)
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
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .padding(10)
            .frame(width: QuickAccessLayout.cardSize.width, height: QuickAccessLayout.cardSize.height)
            .contentShape(Rectangle())
            .onDrag {
                capture.fileURL.flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider()
            }
            .help(capture.fileURL?.lastPathComponent ?? "Not saved to disk")
    }

    private var actionBar: some View {
        HStack(spacing: 2) {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(.tint, in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Edit")
            BarIcon(symbol: copied ? "checkmark" : "doc.on.doc", help: "Copy to clipboard") {
                onCopy()
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    copied = false
                }
            }
            BarIcon(symbol: "square.and.arrow.up", help: "Share") { onShare(shareAnchor.view) }
                .background(AnchorView(holder: shareAnchor))
            Spacer(minLength: 0)
            BarIcon(symbol: "folder", help: "Reveal in Finder", action: onReveal)
                .disabled(capture.fileURL == nil)
            BarIcon(symbol: "trash", help: "Move to Trash", action: onDelete)
                .disabled(capture.fileURL == nil)
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
    }
}

private struct CircleButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 22, height: 22)
                .glassEffect(.regular, in: .circle)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct BarIcon: View {
    let symbol: String
    let help: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
