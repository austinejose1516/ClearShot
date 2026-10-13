import Observation
import ClearShotCore
import SwiftUI

/// Lets the controller play the exit animation before the panel goes away, and show the upload's state.
@Observable
final class CardPresentation {
    var isDismissing = false
    /// The saved file, once it is written (a moment after the card appears).
    var fileURL: URL?
    /// 0…1 while an upload runs; nil otherwise.
    var uploadProgress: Double?
    /// Set once an upload worked, so the card can copy the link again.
    var uploadedLink: URL?
}

/// The card: the screenshot fills it; on hover a glass bar slides up with the actions, plus close and size on top.
struct QuickAccessView: View {
    let capture: Capture
    let presentation: CardPresentation
    let onEdit: () -> Void
    let onCopy: () -> Void
    /// Gets the Share icon's AppKit view, so the Share menu can open under it.
    let onShare: (NSView?) -> Void
    let onUpload: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void
    let onHoverChange: (Bool) -> Void

    @State private var copied = false
    @State private var linkCopied = false
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
                presentation.fileURL.flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider()
            }
            .help(presentation.fileURL?.lastPathComponent ?? "Saving…")
    }

    private var actionBar: some View {
        HStack(spacing: 2) {
            BarIcon(symbol: "pencil", help: "Edit", prominent: true, action: onEdit)
            BarIcon(symbol: copied ? "checkmark" : "doc.on.doc", help: "Copy to clipboard") {
                onCopy()
                flash($copied)
            }
            .symbolEffect(.bounce, value: copied)
            BarIcon(symbol: "square.and.arrow.up", help: "Share") { onShare(shareAnchor.view) }
                .background(AnchorView(holder: shareAnchor))
            ZStack {
                if let progress = presentation.uploadProgress {
                    UploadRing(progress: progress)
                        .frame(width: 28, height: 26)
                        .help("Uploading…")
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else if let link = presentation.uploadedLink {
                    BarIcon(symbol: linkCopied ? "checkmark" : "link", help: "Copy the link again") {
                        UploadService.copy(link)
                        flash($linkCopied)
                    }
                    .symbolEffect(.bounce, value: linkCopied)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    BarIcon(symbol: "icloud.and.arrow.up", help: "Upload to your cloud bucket and copy the link", action: onUpload)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.25), value: presentation.uploadProgress == nil)
            .animation(.snappy(duration: 0.25), value: presentation.uploadedLink)
            Spacer(minLength: 0)
            BarIcon(symbol: "folder", help: "Reveal in Finder", action: onReveal)
                .disabled(presentation.fileURL == nil)
            BarIcon(symbol: "trash", help: "Move to Trash", action: onDelete)
                .disabled(presentation.fileURL == nil)
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
    }

    /// Turns a "done" flag on with a bounce, then off again a moment later.
    private func flash(_ flag: Binding<Bool>) {
        withAnimation(.snappy(duration: 0.2)) { flag.wrappedValue = true }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.2)) { flag.wrappedValue = false }
        }
    }
}

/// A small ring that fills as the upload goes up.
private struct UploadRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(.primary.opacity(0.2), lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(0.03, progress))
                .stroke(.tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 14, height: 14)
        .animation(.linear(duration: 0.15), value: progress)
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

/// One action in the bar; every icon is the same size. `prominent` fills it with the accent colour (Edit).
private struct BarIcon: View {
    let symbol: String
    let help: String
    var prominent = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .contentTransition(.symbolEffect(.replace))
                .font(.system(size: 12, weight: prominent ? .semibold : .medium))
                .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .frame(width: 28, height: 26)
                .background { if prominent { Capsule().fill(.tint) } }
                .contentShape(Capsule())
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
