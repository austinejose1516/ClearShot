import AVKit
import ClearShotCore
import SwiftUI

/// The player on top, the trim bar and the actions below.
struct VideoView: View {
    static let minimumSize = NSSize(width: 760, height: 520)
    static let defaultSize = NSSize(width: 960, height: 660)

    let state: VideoState
    let player: AVPlayer
    let encoding: VideoEncoding.Settings
    let onCommand: (VideoCommand) -> Void
    let onRangeChanged: (TrimRange) -> Void
    let onSeek: (Double) -> Void
    let onCancelExport: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PlayerView(player: player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
            Divider()
            VStack(spacing: 10) {
                TrimBar(state: state, onRangeChanged: onRangeChanged, onSeek: onSeek)
                    .frame(height: 64)
                actions
            }
            .padding(14)
        }
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
    }

    private var exporting: Bool { state.exportProgress != nil }

    private var actions: some View {
        HStack(spacing: 10) {
            if let progress = state.exportProgress {
                ProgressView(value: progress).progressViewStyle(.linear).frame(width: 160)
                Text("Preparing the video…").foregroundStyle(.secondary)
                Button("Cancel", action: onCancelExport)
            } else {
                Text("\(Self.clock(state.range.start, decimals: true)) – \(Self.clock(state.range.end, decimals: true))")
                    .font(.body.monospacedDigit())
                Text("·").foregroundStyle(.tertiary)
                Text("\(Self.clock(state.range.duration)) kept").foregroundStyle(.secondary)
                Button("Start Here") { change(state.range.movingStart(to: state.playhead)) }
                    .help("Move the start to the playhead")
                Button("End Here") { change(state.range.movingEnd(to: state.playhead)) }
                    .help("Move the end to the playhead")
                Button("Reset") { change(.whole(total: state.total)) }
                    .disabled(state.range.isWhole)
            }
            Spacer(minLength: 8)
            Text("up to ≈ \(ByteCountFormatter.string(fromByteCount: Int64(encoding.estimatedBytes(seconds: state.range.duration)), countStyle: .file))")
                .foregroundStyle(.secondary)
                .help("The most the file can be. Still parts of the screen make it smaller.")
            Menu {
                Button("Save As…") { onCommand(.saveAs) }
            } label: {
                Label("Save", systemImage: "square.and.arrow.down").labelStyle(.titleAndIcon).padding(.horizontal, 2)
            } primaryAction: {
                onCommand(.save)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .fixedSize()
            .disabled(exporting)
            .help("Save to your folder and close (⌘S). Arrow: Save As… (⇧⌘S)")
        }
        .controlSize(.regular)
    }

    private func change(_ range: TrimRange) {
        state.range = range
        onRangeChanged(range)
    }

    /// "0:42" or, with decimals, "0:03.2".
    static func clock(_ seconds: Double, decimals: Bool = false) -> String {
        let whole = Int(seconds)
        let minutes = whole / 60
        if decimals {
            return String(format: "%d:%04.1f", minutes, seconds - Double(minutes * 60))
        }
        return String(format: "%d:%02d", minutes, whole % 60)
    }
}

/// The filmstrip with two handles. Outside the handles is dimmed; a white line is the playhead; a click seeks.
struct TrimBar: View {
    let state: VideoState
    let onRangeChanged: (TrimRange) -> Void
    let onSeek: (Double) -> Void

    private let handleWidth: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let startX = TrimBarGeometry.x(forSeconds: state.range.start, width: width, total: state.total)
            let endX = TrimBarGeometry.x(forSeconds: state.range.end, width: width, total: state.total)
            let playX = TrimBarGeometry.x(forSeconds: state.playhead, width: width, total: state.total)
            ZStack(alignment: .leading) {
                filmstrip(width: width, height: height)
                Rectangle().fill(.black.opacity(0.55)).frame(width: max(0, startX))
                Rectangle().fill(.black.opacity(0.55)).frame(width: max(0, width - endX)).offset(x: endX)
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.tint, lineWidth: 2)
                    .frame(width: max(0, endX - startX))
                    .offset(x: startX)
                    .allowsHitTesting(false)
                Rectangle()
                    .fill(.white)
                    .frame(width: 2, height: height)
                    .offset(x: playX - 1)
                    .shadow(color: .black.opacity(0.6), radius: 1)
                    .allowsHitTesting(false)
                handle(height: height)
                    .offset(x: startX - handleWidth / 2)
                    .gesture(drag(width: width) { state.range.movingStart(to: $0) })
                    .help("Drag to set the start")
                handle(height: height)
                    .offset(x: endX - handleWidth / 2)
                    .gesture(drag(width: width) { state.range.movingEnd(to: $0) })
                    .help("Drag to set the end")
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .coordinateSpace(name: "bar")
            .onTapGesture { location in
                onSeek(TrimBarGeometry.seconds(atX: location.x, width: width, total: state.total))
            }
        }
    }

    private func filmstrip(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            let count = max(1, VideoWindowController.thumbnailCount)
            ForEach(0..<count, id: \.self) { index in
                if index < state.thumbnails.count, let image = state.thumbnails[index] {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width / CGFloat(count), height: height)
                        .clipped()
                } else {
                    Rectangle().fill(.quaternary).frame(width: width / CGFloat(count), height: height)
                }
            }
        }
    }

    private func handle(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.tint)
            .frame(width: handleWidth, height: height)
            .overlay(Capsule().fill(.white.opacity(0.9)).frame(width: 2, height: height * 0.4))
            .contentShape(Rectangle().inset(by: -6))
    }

    private func drag(width: CGFloat, _ move: @escaping (Double) -> TrimRange) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("bar"))
            .onChanged { value in
                let range = move(TrimBarGeometry.seconds(atX: value.location.x, width: width, total: state.total))
                guard range != state.range else { return }
                state.range = range
                onRangeChanged(range)
            }
    }
}

/// AVKit's AppKit player view (its SwiftUI `VideoPlayer` aborts at launch on this macOS build).
private struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .inline
        view.showsFullScreenToggleButton = false
        view.allowsPictureInPicturePlayback = false
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player { view.player = player }
    }
}
