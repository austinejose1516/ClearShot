import AppKit
import AVFoundation
import AVKit
import ClearShotCore
import SwiftUI

/// What the video window's keys and buttons can ask for.
enum VideoCommand {
    case save, saveAs
}

/// What the video window shows: the trim range, the playhead, the filmstrip and the export's progress.
@Observable
final class VideoState {
    let total: Double
    var range: TrimRange
    var playhead: Double = 0
    var thumbnails: [CGImage?] = []
    /// 0…1 while an export runs; nil otherwise.
    var exportProgress: Double?

    init(total: Double) {
        self.total = total
        range = .whole(total: total)
    }
}

/// One recording's window: play it, trim it, then Save, Save As, Share or Upload. Nothing is written until then;
/// closing without saving asks first and then deletes the temp file.
final class VideoWindowController: NSWindowController, NSWindowDelegate {
    static let thumbnailCount = 12

    private let recordingURL: URL
    private let encoding: VideoEncoding.Settings
    private let settings: AppSettings
    private let state: VideoState
    private let player: AVPlayer
    private let onClosed: (VideoWindowController) -> Void
    private var saved = false
    private var exportTask: Task<URL, any Error>?
    private var lastExport: (range: TrimRange, url: URL)?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    /// Loads the recording's length first, so the window opens with the right range.
    static func make(recordingURL: URL, encoding: VideoEncoding.Settings, settings: AppSettings,
                     onClosed: @escaping (VideoWindowController) -> Void) async throws -> VideoWindowController {
        let total = try await CMTimeGetSeconds(AVURLAsset(url: recordingURL).load(.duration))
        guard total > 0 else { throw VideoExporter.Failure.noVideoTrack }
        return VideoWindowController(recordingURL: recordingURL, total: total, encoding: encoding, settings: settings, onClosed: onClosed)
    }

    private init(recordingURL: URL, total: Double, encoding: VideoEncoding.Settings, settings: AppSettings,
                 onClosed: @escaping (VideoWindowController) -> Void) {
        self.recordingURL = recordingURL
        self.encoding = encoding
        self.settings = settings
        self.onClosed = onClosed
        state = VideoState(total: total)
        player = AVPlayer(url: recordingURL)
        let window = VideoWindow(
            contentRect: NSRect(origin: .zero, size: VideoView.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "Recording · \(VideoView.clock(total))"
        window.minSize = VideoView.minimumSize
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.onCommand = { [weak self] in self?.perform($0) }
        let host = NSHostingController(rootView: VideoView(
            state: state,
            player: player,
            encoding: encoding,
            onCommand: { [weak self] in self?.perform($0) },
            onRangeChanged: { [weak self] in self?.rangeChanged($0) },
            onSeek: { [weak self] in self?.seek(to: $0) },
            onCancelExport: { [weak self] in self?.exportTask?.cancel() })
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
        switch command {
        case .save: save()
        case .saveAs: saveAs()
        }
    }

    // MARK: - Playback

    private func watchPlayback() {
        let state = state
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 20), queue: .main) { time in
            MainActor.assumeIsolated { state.playhead = CMTimeGetSeconds(time) }
        }
        rangeChanged(state.range)
        let player = player
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: player.currentItem, queue: .main
        ) { _ in
            // The end of the kept part: back to its start, ready to play again.
            MainActor.assumeIsolated {
                player.seek(to: CMTime(seconds: state.range.start, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
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

    private func loadThumbnails() {
        let state = state
        let url = recordingURL
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

    /// The trimmed, re-encoded file in the temp folder. The last one is reused while the range is unchanged, so
    /// Upload then Save does not encode twice.
    private func exportIfNeeded() async throws -> URL {
        if let lastExport, lastExport.range == state.range { return lastExport.url }
        exportTask?.cancel()
        let range = state.range
        let encoding = encoding
        let source = recordingURL
        let target = TemporaryFiles.recordingsFolder.appending(path: source.deletingPathExtension().lastPathComponent + " export.mp4")
        let state = state
        state.exportProgress = 0
        let started = ContinuousClock.now
        let task = Task.detached(priority: .userInitiated) {
            try await VideoExporter.export(from: source, range: range, encoding: encoding, to: target) { fraction in
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
        DiagnosticLog.write("exported \(range.duration.formatted(.number.precision(.fractionLength(1)))) s at "
                            + "\(encoding.width)x\(encoding.height): \(bytes / 1024) KB in "
                            + "\((ContinuousClock.now - started).formatted(.units(allowed: [.seconds, .milliseconds])))")
        lastExport = (range, url)
        return url
    }

    private func save() {
        guard state.exportProgress == nil else { return }
        Task {
            do {
                let exported = try await exportIfNeeded()
                let url = try FileSaver.reserveURL(fileExtension: "mp4", in: settings.saveFolder)
                try FileManager.default.copyItem(at: exported, to: url)
                DiagnosticLog.write("recording saved to \(url.path(percentEncoded: false))")
                didSave()
            } catch is CancellationError {
            } catch {
                ErrorPresenter.show(title: "Could not save the recording", message: error.localizedDescription)
            }
        }
    }

    private func saveAs() {
        guard state.exportProgress == nil else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = FileNamer.fileName(date: .now, fileExtension: "mp4")
        panel.directoryURL = settings.saveFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                let exported = try await exportIfNeeded()
                if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                    _ = try FileManager.default.replaceItemAt(url, withItemAt: exported)
                    lastExport = nil   // the export moved; the next Save makes a new one
                } else {
                    try FileManager.default.copyItem(at: exported, to: url)
                }
                DiagnosticLog.write("recording saved to \(url.path(percentEncoded: false))")
                didSave()
            } catch is CancellationError {
            } catch {
                ErrorPresenter.show(title: "Could not save the recording", message: error.localizedDescription)
            }
        }
    }

    private func didSave() {
        saved = true
        Toast.show("Saved")
        close()
    }

    // MARK: - Closing

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !saved else { return true }
        let alert = NSAlert()
        alert.messageText = "Discard this recording?"
        alert.informativeText = "It is not saved anywhere yet."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Discard").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func windowWillClose(_ notification: Notification) {
        exportTask?.cancel()
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        try? FileManager.default.removeItem(at: recordingURL)
        if let lastExport { try? FileManager.default.removeItem(at: lastExport.url) }
        DiagnosticLog.write("recording window closed (\(saved ? "saved" : "discarded"))")
        onClosed(self)
    }
}

/// A menu-bar app has no File menu, so the window turns ⌘S and ⇧⌘S into commands itself.
final class VideoWindow: NSWindow {
    var onCommand: ((VideoCommand) -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "s" else {
            return super.performKeyEquivalent(with: event)
        }
        onCommand?(flags.contains(.shift) ? .saveAs : .save)
        return true
    }
}
