import AppKit
import AVFoundation
import AVKit
import ClearShotCore
import SwiftUI

/// What the video editor's keys and buttons can ask for. Copy, Share and Upload are on the card.
enum VideoCommand {
    case done
    /// The Blur switch: on, the mouse draws and moves boxes over the video.
    case toggleBlurTool
    /// ⌫: the selected box goes.
    case deleteSelection
    /// Esc: the selection clears and the Blur switch turns off.
    case escape
    /// The Frame switch: the panel on the right.
    case toggleFramePanel
}

/// What the card needs after the video editor saved: the new length, first frame and size, and where the file is.
struct VideoSaveResult {
    let duration: Double
    let poster: CGImage
    let encoding: VideoEncoding.Settings
    let url: URL
}

/// What the video editor shows: the trim range, the playhead, the filmstrip, the blur boxes and the export's
/// progress.
@Observable
final class VideoState {
    let total: Double
    var range: TrimRange
    var playhead: Double = 0
    var thumbnails: [CGImage?] = []
    /// 0…1 while the trimmed cut is made; nil otherwise.
    var exportProgress: Double?
    var blurs: VideoBlurs
    var selectedBlur: VideoBlur.ID?
    var blurToolOn = false
    /// What a new box gets: the last mode picked.
    var blurMode: BlurMode = .blur
    /// The recording's size in pixels.
    let videoSize: CGSize
    /// Background, padding, corners and shadow around the video, for the whole clip.
    var frame = FrameStyle()
    var showsFramePanel = false

    init(total: Double, frame: CGSize) {
        self.total = total
        range = .whole(total: total)
        blurs = VideoBlurs(frame: frame)
        videoSize = frame
    }

    var hasEdits: Bool { !range.isWhole || !blurs.isEmpty || frame != FrameStyle() }

    /// Where the video sits on the output: padding grows the picture around it.
    var layout: CanvasLayout { CanvasLayout(imageSize: videoSize, frame: frame) }
}

/// The Frame panel's view of a recording: live changes go to the state, and the editor redraws.
final class VideoFrameEditing: FrameEditing {
    private let state: VideoState
    /// `committed` is false for a slider mid-drag, true once it settles (or for a button).
    var onChanged: ((_ committed: Bool) -> Void)?

    init(state: VideoState) {
        self.state = state
    }

    var frame: FrameStyle { state.frame }

    func setFrame(_ frame: FrameStyle) {
        state.frame = frame
        onChanged?(false)
    }

    func commit() {
        onChanged?(true)
    }
}

/// The video editor, opened with Edit on a recording's card: play, trim, blur, then Done, which writes the
/// result into the card's file. Like the screenshot editor, everything else is on the card: Copy, Share and Upload.
final class VideoWindowController: NSWindowController, NSWindowDelegate {
    static let thumbnailCount = 12

    private let fileURL: URL
    private let encoding: VideoEncoding.Settings
    private let settings: AppSettings
    private let state: VideoState
    private let player: AVPlayer
    /// Nil when there was nothing to save (no trim): the editor just goes back to the card.
    private let onSaved: (VideoSaveResult?) -> Void
    /// The close button: the store shrinks the editor back into its card first.
    private let onCloseRequest: () -> Void
    private let onWindowClosed: () -> Void
    private var exportTask: Task<URL, any Error>?
    private var lastExport: (range: TrimRange, blurs: VideoBlurs, frame: FrameStyle, url: URL)?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var saved = false
    /// What the player draws (boxes, frame); it reads the latest on every frame.
    private let composer: VideoComposer
    private let frameEditing: VideoFrameEditing
    private var previewTask: Task<Void, Never>?

    /// A trim or blur boxes not saved yet; they are kept while the card can reopen the editor.
    var hasUnsavedEdits: Bool { !saved && state.hasEdits }

    init(fileURL: URL, video: Capture.Video, settings: AppSettings,
         onSaved: @escaping (VideoSaveResult?) -> Void, onCloseRequest: @escaping () -> Void,
         onWindowClosed: @escaping () -> Void) {
        self.fileURL = fileURL
        self.encoding = video.encoding
        self.settings = settings
        self.onSaved = onSaved
        self.onCloseRequest = onCloseRequest
        self.onWindowClosed = onWindowClosed
        state = VideoState(total: video.duration, frame: CGSize(width: video.encoding.width, height: video.encoding.height))
        composer = VideoComposer(blurs: state.blurs, frame: FrameStyle())
        frameEditing = VideoFrameEditing(state: state)
        player = AVPlayer(url: fileURL)
        let window = VideoWindow(
            contentRect: NSRect(origin: .zero, size: VideoView.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = fileURL.lastPathComponent
        window.minSize = VideoView.minimumSize
        window.isReleasedWhenClosed = false
        // Opens on the Space you are on, also over an app in full screen, like the card it grew from.
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        super.init(window: window)
        window.delegate = self
        window.onCommand = { [weak self] in self?.perform($0) }
        window.onKey = { [weak self] in self?.handleKey($0) ?? false }
        frameEditing.onChanged = { [weak self] committed in self?.refreshPreview(resizing: committed) }
        let host = NSHostingController(rootView: VideoView(
            state: state,
            player: player,
            encoding: encoding,
            frameEditing: frameEditing,
            onCommand: { [weak self] in self?.perform($0) },
            onRangeChanged: { [weak self] in self?.rangeChanged($0) },
            onSeek: { [weak self] in self?.seek(to: $0) },
            onCancelExport: { [weak self] in self?.exportTask?.cancel() },
            onBlursChanged: { [weak self] in self?.refreshPreview() })
            .themed(settings))
        host.sizingOptions = .minSize
        window.contentViewController = host
        window.setContentSize(VideoView.defaultSize)
        window.center()
        watchPlayback()
        loadThumbnails()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    func perform(_ command: VideoCommand) {
        guard state.exportProgress == nil else { return }
        switch command {
        case .done:
            done()
        case .toggleBlurTool:
            state.blurToolOn.toggle()
            if !state.blurToolOn { state.selectedBlur = nil }
        case .deleteSelection:
            guard let id = state.selectedBlur else { return }
            state.blurs.remove(id)
            state.selectedBlur = nil
            refreshPreview()
        case .escape:
            state.selectedBlur = nil
            state.blurToolOn = false
        case .toggleFramePanel:
            state.showsFramePanel.toggle()
            // Opened on an untouched frame: the starter, so every control shows an effect (as for screenshots).
            if state.showsFramePanel, state.frame == FrameStyle() {
                state.frame = .starter
                refreshPreview()
            }
        }
    }

    /// The output: the video plus the frame's padding, at even sizes, with the bitrate to match.
    private var outputEncoding: VideoEncoding.Settings { encoding.resized(to: state.layout.canvasSize) }
    private var outputSize: CGSize { CGSize(width: outputEncoding.width, height: outputEncoding.height) }

    /// ⌫ and Esc while blurring; everything else goes on to the player.
    private func handleKey(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case 51, 117:   // delete, forward delete
            guard state.selectedBlur != nil else { return false }
            perform(.deleteSelection)
        case 53:   // escape
            guard state.blurToolOn || state.selectedBlur != nil else { return false }
            perform(.escape)
        default:
            return false
        }
        return true
    }

    /// Where the video is on screen: fitted in the player, between the top bar and the trim bar. The card
    /// animation flies the first frame to and from here.
    func pictureFrameOnScreen() -> CGRect? {
        guard let window else { return nil }
        let content = window.contentLayoutRect
        let bottom = VideoView.trimAreaHeight + 1
        let panel = state.showsFramePanel ? FramePanelView.width + 1 : 0
        let player = CGRect(x: content.minX, y: content.minY + bottom,
                            width: content.width - panel, height: content.height - bottom - VideoView.actionsHeight - 1)
        return window.convertToScreen(AspectFit.rect(for: state.layout.canvasSize, in: player))
    }

    // MARK: - Playback

    private func watchPlayback() {
        let state = state
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 20), queue: .main) { time in
            MainActor.assumeIsolated { state.playhead = CMTimeGetSeconds(time) }
        }
        rangeChanged(state.range)
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: player.currentItem, queue: .main
        ) { [weak player] _ in
            // The end of the kept part: back to its start, ready to play again.
            MainActor.assumeIsolated {
                player?.seek(to: CMTime(seconds: state.range.start, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }

    /// Playback stays inside the kept part.
    private func rangeChanged(_ range: TrimRange) {
        guard let item = player.currentItem else { return }
        item.forwardPlaybackEndTime = CMTime(seconds: range.end, preferredTimescale: 600)
        if state.playhead < range.start || state.playhead > range.end {
            seek(to: range.start)
        }
    }

    private func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Blur preview

    /// The player draws the boxes and the frame through a video composition. A paused player does not redraw by
    /// itself, so the frame is sought again at the same time. The composition carries the output size, so when
    /// padding changed it it is made again; `resizing` false (a slider mid-drag) waits for the drag to settle.
    private func refreshPreview(resizing: Bool = true) {
        composer.update(blurs: state.blurs, frame: state.frame)
        guard let item = player.currentItem else { return }
        previewTask?.cancel()
        let needsComposition = !composer.edits.isEmpty
        let renderSize = outputSize
        let player = player
        let composer = composer
        let sizeChanged = item.videoComposition.map { $0.renderSize != renderSize } ?? true
        previewTask = Task {
            if needsComposition, sizeChanged, resizing || item.videoComposition == nil {
                guard let composition = try? await VideoComposer.composition(for: item.asset, composer: composer, renderSize: renderSize),
                      !Task.isCancelled else { return }
                item.videoComposition = composition
            } else if !needsComposition {
                item.videoComposition = nil
            }
            let now = player.currentTime()
            await player.seek(to: now, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    private func loadThumbnails() {
        let state = state
        let url = fileURL
        let times = TrimBarGeometry.thumbnailTimes(count: Self.thumbnailCount, total: state.total)
        Task.detached(priority: .utility) {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 0, height: 160)
            var images: [CGImage?] = []
            for await result in generator.images(for: times.map { CMTime(seconds: $0, preferredTimescale: 600) }) {
                images.append(try? result.image)
            }
            let done = images
            await MainActor.run { state.thumbnails = done }
        }
    }

    // MARK: - Output

    /// The file as it is when nothing is edited; otherwise the trimmed, blurred cut, re-encoded into the temp
    /// folder. The last cut is reused while nothing changed, so pressing Done again does not encode twice.
    private func result() async throws -> URL {
        if !state.hasEdits { return fileURL }
        if let lastExport, lastExport.range == state.range, lastExport.blurs == state.blurs, lastExport.frame == state.frame {
            return lastExport.url
        }
        exportTask?.cancel()
        let range = state.range
        let blurs = state.blurs
        let frame = state.frame
        let encoding = outputEncoding
        let source = fileURL
        let target = TemporaryFiles.recordingsFolder.appending(path: "\(UUID().uuidString) trim.mp4")
        let state = state
        state.exportProgress = 0
        let started = ContinuousClock.now
        let task = Task.detached(priority: .userInitiated) {
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try await VideoExporter.export(from: AVURLAsset(url: source), range: range, encoding: encoding,
                                           composer: VideoComposer(blurs: blurs, frame: frame), to: target) { fraction in
                Task { @MainActor in state.exportProgress = fraction }
            }
            return target
        }
        exportTask = task
        defer {
            state.exportProgress = nil
            if exportTask == task { exportTask = nil }
        }
        let url = try await task.value
        let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))[.size] as? Int) ?? 0
        DiagnosticLog.write("trimmed \(VideoTime.length(range.duration)) at \(encoding.width)x\(encoding.height)"
                            + "\(blurs.isEmpty ? "" : ", \(blurs.regions.count) blur boxes")\(frame == FrameStyle() ? "" : ", framed")"
                            + ": \(bytes / 1024) KB in "
                            + "\((ContinuousClock.now - started).formatted(.units(allowed: [.seconds, .milliseconds])))")
        if let lastExport { try? FileManager.default.removeItem(at: lastExport.url) }
        lastExport = (range, blurs, frame, url)
        return url
    }

    /// Nothing edited: just back to the card. Trimmed or blurred: the cut replaces the card's file.
    private func done() {
        guard hasUnsavedEdits else { return onSaved(nil) }
        run("Could not save the recording") { [self] in
            let cut = try await result()
            player.replaceCurrentItem(with: nil)   // let go of the file before it is replaced
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: cut)
            lastExport = nil   // the cut moved into place
            DiagnosticLog.write("recording trimmed and saved to \(fileURL.path(percentEncoded: false))")
            try await didSave(fileURL)
        }
    }

    /// The card follows the saved file: its length and first frame.
    private func didSave(_ url: URL) async throws {
        saved = true
        let duration = try await CMTimeGetSeconds(AVURLAsset(url: url).load(.duration))
        guard let poster = await RecordingFinisher.poster(of: url) else { return onSaved(nil) }
        onSaved(VideoSaveResult(duration: duration, poster: poster, encoding: outputEncoding, url: url))
    }

    /// Runs an output step; a cancelled export is quiet, anything else is shown.
    private func run(_ failure: String, _ work: @escaping @MainActor () async throws -> Void) {
        Task {
            do {
                try await work()
            } catch is CancellationError {
            } catch {
                ErrorPresenter.show(title: failure, message: error.localizedDescription)
            }
        }
    }

    // MARK: - Closing

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onCloseRequest()
        return false   // the store closes it once it is back in the card
    }

    /// Closing keeps the trim (the store decides whether the editor lives on); only the playback stops.
    func windowWillClose(_ notification: Notification) {
        exportTask?.cancel()
        player.pause()
        onWindowClosed()
    }

    /// The store is done with this editor: stop watching playback and remove the temp cut.
    func release() {
        exportTask?.cancel()
        previewTask?.cancel()
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
        if let lastExport { try? FileManager.default.removeItem(at: lastExport.url) }
        lastExport = nil
    }
}

/// A menu-bar app has no File menu, so the window turns ⌘S into Done itself, like the screenshot editor.
/// ⌫ and Esc are offered to the editor first (`onKey` says whether it took them), then go on as usual.
final class VideoWindow: NSWindow {
    var onCommand: ((VideoCommand) -> Void)?
    var onKey: ((UInt16) -> Bool)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
           onKey?(event.keyCode) == true {
            return
        }
        super.sendEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), !flags.contains(.shift), event.charactersIgnoringModifiers?.lowercased() == "s" else {
            return super.performKeyEquivalent(with: event)
        }
        onCommand?(.done)
        return true
    }
}
