import AVKit
import ClearShotCore
import SwiftUI

/// Done and the Blur switch on top (like the screenshot editor), the player in the middle with the blur boxes
/// over it, the trim bar below.
struct VideoView: View {
    static let minimumSize = NSSize(width: 760, height: 520)
    static let defaultSize = NSSize(width: 960, height: 680)
    static let actionsHeight: CGFloat = 48
    static let trimBarHeight: CGFloat = 56
    static let trimPadding: CGFloat = 12
    /// The trim bar and the space around it, under the player.
    static let trimAreaHeight = trimBarHeight + 2 * trimPadding

    let state: VideoState
    let player: AVPlayer
    let encoding: VideoEncoding.Settings
    let onCommand: (VideoCommand) -> Void
    let onRangeChanged: (TrimRange) -> Void
    let onSeek: (Double) -> Void
    let onCancelExport: () -> Void
    /// A box was added, moved, resized, removed or changed mode: the player redraws.
    let onBlursChanged: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            actions
            Divider()
            ZStack {
                PlayerView(player: player)
                VideoBlurOverlay(state: state, videoSize: CGSize(width: encoding.width, height: encoding.height),
                                 onChanged: onBlursChanged)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            Divider()
            trim
        }
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
    }

    private var busy: Bool { state.exportProgress != nil }

    // MARK: - Top: the Blur switch and Done, like the screenshot editor

    private var actions: some View {
        HStack(spacing: 8) {
            Label(VideoTime.clock(state.total), systemImage: "video")
                .labelStyle(.titleAndIcon)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            Divider().frame(height: 20).padding(.horizontal, 4)
            Toggle(isOn: Binding(get: { state.blurToolOn }, set: { _ in onCommand(.toggleBlurTool) })) {
                Label("Blur", systemImage: "eye.slash").labelStyle(.titleAndIcon)
            }
            .toggleStyle(.button)
            .buttonBorderShape(.capsule)
            .help("Drag a box over the part to hide, for the whole clip (Esc turns it off)")
            blurOptions
            Spacer(minLength: 12)
            DoneButton { onCommand(.done) }
        }
        .disabled(busy)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .frame(height: Self.actionsHeight)
        .background(.bar)
    }

    /// With a box selected: its mode and Remove. With the switch on and nothing selected: what to do.
    @ViewBuilder private var blurOptions: some View {
        if let id = state.selectedBlur, let region = state.blurs[id] {
            Picker("Mode", selection: Binding(get: { region.mode }, set: { mode in
                state.blurs.setMode(mode, of: id)
                state.blurMode = mode
                onBlursChanged()
            })) {
                Text("Blur").tag(BlurMode.blur)
                Text("Pixelate").tag(BlurMode.pixelate)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 150)
            Button { onCommand(.deleteSelection) } label: {
                Label("Remove", systemImage: "trash").labelStyle(.titleAndIcon)
            }
            .buttonBorderShape(.capsule)
            .help("Remove this box (⌫)")
        } else if state.blurToolOn {
            Text("Drag over the part to hide")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Bottom: the trim bar

    private var trim: some View {
        HStack(spacing: 14) {
            TrimBar(state: state, onRangeChanged: onRangeChanged, onSeek: onSeek)
                .frame(height: Self.trimBarHeight)
            Group {
                if let progress = state.exportProgress {
                    HStack(spacing: 8) {
                        ProgressView(value: progress).progressViewStyle(.linear)
                        Button("Cancel", action: onCancelExport).controlSize(.small)
                    }
                    .help("Making the trimmed video")
                } else {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        Text("\(VideoTime.length(state.range.duration)) kept · ≈ \(ByteCountFormatter.string(fromByteCount: Int64(encoding.estimatedBytes(seconds: state.range.duration)), countStyle: .file))")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .help("The most the file can be. Still parts of the screen make it smaller.")
                        if !state.range.isWhole {
                            Button { change(.whole(total: state.total)) } label: {
                                Image(systemName: "arrow.counterclockwise")
                            }
                            .buttonStyle(.borderless)
                            .help("Keep the whole recording")
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .frame(width: 210, alignment: .trailing)
            .animation(.snappy(duration: 0.2), value: state.range.isWhole)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, Self.trimPadding)
    }

    private func change(_ range: TrimRange) {
        state.range = range
        onRangeChanged(range)
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
