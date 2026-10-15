import AVFoundation
import Observation
import ClearShotCore
import SwiftUI

/// Lets the controller play the exit animation before the panel goes away, show the upload's state, and
/// swap in what an editor saved.
@Observable
final class CardPresentation {
    /// The picture on the card: the capture, or the editor's saved result (a recording's first frame).
    var image: CGImage
    /// A recording's length, for the badge; nil for a screenshot.
    var videoDuration: Double?
    /// Goes up by one each time an editor saves into this card: the card bounces and says Saved.
    var savedCount = 0
    /// The card is an editor right now (hidden): it forgets the mouse, which left with it.
    var isAway = false
    var isDismissing = false
    /// The saved file, once it is written (a moment after the card appears; longer for a recording).
    var fileURL: URL?
    /// 0…1 while a recording is compressed into its file; nil otherwise.
    var saveProgress: Double?
    /// 0…1 while an upload runs; nil otherwise.
    var uploadProgress: Double?
    /// Set once an upload worked, so the card can copy the link again.
    var uploadedLink: URL?

    init(image: CGImage, videoDuration: Double?) {
        self.image = image
        self.videoDuration = videoDuration
    }
}

/// The card: the screenshot (or a recording's first frame) fills it; on hover a glass bar slides up with the
/// actions, plus close and size on top. A recording shows its length at all times and plays while hovered.
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
    @State private var showsSaved = false
    @State private var shareAnchor = AnchorHolder()

    var body: some View {
        let dismissing = presentation.isDismissing
        let size = QuickAccessLayout.cardSize
        ZStack {
            thumbnail
            if showsSaved {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
            if let progress = presentation.saveProgress {
                HStack(spacing: 6) {
                    UploadRing(progress: progress)
                    Text("Saving").font(.caption.weight(.medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)
                .help("Making the video small")
                .transition(.opacity)
            }
            VStack(spacing: 0) {
                HStack {
                    if hovered {
                        CircleButton(symbol: "xmark", help: "Close", action: onClose)
                            .transition(.opacity)
                    }
                    Spacer()
                    if hovered || capture.isVideo {
                        badge.transition(.opacity)
                    }
                }
                Spacer(minLength: 0)
                if hovered {
                    actionBar.transition(.opacity.combined(with: .offset(y: 8)))
                }
            }
            .padding(8)
        }
        .frame(width: size.width, height: size.height)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.18)))
        .scaleEffect(dismissing ? 0.88 : (appeared ? (hovered || showsSaved ? 1.03 : 1) : 0.8))
        .opacity(dismissing ? 0 : (appeared ? 1 : 0))
        .offset(y: dismissing ? 18 : (appeared ? 0 : 36))
        .padding(QuickAccessLayout.panelMargin)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: appeared)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hovered)
        .animation(.easeIn(duration: 0.22), value: dismissing)
        .animation(.easeOut(duration: 0.2), value: presentation.saveProgress == nil)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: showsSaved)
        .onChange(of: presentation.savedCount) { flash($showsSaved) }
        .onChange(of: presentation.isAway) { _, away in if away { hovered = false } }
        .onAppear { appeared = true }
        .onHover { inside in
            hovered = inside
            onHoverChange(inside)
        }
    }

    /// Pixel size for a screenshot; "▶ 0:42" for a recording.
    private var badge: some View {
        Group {
            if let duration = presentation.videoDuration {
                Label(VideoTime.clock(duration), systemImage: "play.fill")
                    .labelStyle(.titleAndIcon)
                    .imageScale(.small)
            } else {
                Text("\(presentation.image.width) × \(presentation.image.height)")
            }
        }
        .font(.caption2.monospacedDigit().weight(.medium))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .glassEffect(.regular, in: .capsule)
    }

    private var thumbnail: some View {
        Image(decorative: presentation.image, scale: 1)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay {
                // A recording plays, muted, while the mouse is over its card (once its file is saved).
                if capture.isVideo, hovered, let url = presentation.fileURL {
                    LoopingVideo(url: url).transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .padding(QuickAccessLayout.thumbnailPadding)
            .frame(width: QuickAccessLayout.cardSize.width, height: QuickAccessLayout.cardSize.height)
            .contentShape(Rectangle())
            .onDrag {
                presentation.fileURL.flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider()
            }
            .help(presentation.fileURL?.lastPathComponent ?? "Saving…")
    }

    private var actionBar: some View {
        // A recording's actions all need its file, which is written a little after the card appears.
        let waiting = capture.isVideo && presentation.fileURL == nil
        return HStack(spacing: 2) {
            BarIcon(symbol: "pencil", help: capture.isVideo ? "Edit (trim)" : "Edit", prominent: true, action: onEdit)
                .disabled(waiting)
            BarIcon(symbol: copied ? "checkmark" : "doc.on.doc", help: capture.isVideo ? "Copy the video file" : "Copy to clipboard") {
                onCopy()
                flash($copied)
            }
            .symbolEffect(.bounce, value: copied)
            .disabled(waiting)
            BarIcon(symbol: "square.and.arrow.up", help: "Share") { onShare(shareAnchor.view) }
                .background(AnchorView(holder: shareAnchor))
                .disabled(waiting)
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
                        .disabled(waiting)
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

/// A recording's file on a loop, muted, drawn by AVFoundation's player layer (AVKit's SwiftUI player aborts on
/// this macOS build).
private struct LoopingVideo: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> LoopingPlayerView {
        LoopingPlayerView(url: url)
    }

    func updateNSView(_ view: LoopingPlayerView, context: Context) {}

    static func dismantleNSView(_ view: LoopingPlayerView, coordinator: ()) {
        view.stop()
    }
}

final class LoopingPlayerView: NSView {
    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init(url: URL) {
        super.init(frame: .zero)
        wantsLayer = true
        (layer as? AVPlayerLayer)?.videoGravity = .resizeAspect
        player.isMuted = true
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.play()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override func makeBackingLayer() -> CALayer {
        AVPlayerLayer(player: player)
    }

    func stop() {
        player.pause()
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
    }
}

/// A small ring that fills as the upload (or a recording's save) goes up.
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
