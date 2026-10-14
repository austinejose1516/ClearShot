import AppKit
import AVFoundation
import ClearShotCore
import ScreenCaptureKit

/// Starts and stops one screen recording at a time: picks what to record, runs the recorder, shows the bar and
/// the frame, and hands the finished temp file on.
@Observable
final class RecordingCoordinator {
    enum State {
        case idle, choosing, recording(since: Date), finishing
    }

    private(set) var state: State = .idle

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    private let settings: AppSettings
    private let onPermissionMissing: () -> Void
    private var recorder: ScreenRecorder?
    private var encoding: VideoEncoding.Settings?
    private var bar: RecordingBarPanel?
    private var frame: RegionFramePanel?

    /// The finished recording: the temp file and the size it was recorded at.
    var onFinished: ((URL, VideoEncoding.Settings) -> Void)?

    init(settings: AppSettings, onPermissionMissing: @escaping () -> Void) {
        self.settings = settings
        self.onPermissionMissing = onPermissionMissing
    }

    /// The hotkey: start an area recording, or stop the one running.
    func toggle() {
        if isRecording { stop() } else { start(.area) }
    }

    func start(_ kind: CaptureKind) {
        guard PermissionService.hasScreenRecordingAccess else {
            DiagnosticLog.write("record(\(kind.rawValue)) blocked: no Screen Recording access")
            onPermissionMissing()
            return
        }
        guard case .idle = state else { return }
        state = .choosing
        DiagnosticLog.write("record(\(kind.rawValue)) choosing")
        Task {
            do {
                guard let target = try await chooseTarget(kind) else {
                    DiagnosticLog.write("record(\(kind.rawValue)) cancelled")
                    state = .idle
                    return
                }
                try await begin(target)
            } catch {
                state = .idle
                DiagnosticLog.write("record(\(kind.rawValue)) failed to start: \(error)")
                ErrorPresenter.show(title: "Could not start recording", message: error.localizedDescription)
            }
        }
    }

    func stop() {
        finish(streamAlreadyStopped: false)
    }

    // MARK: - Choosing

    private enum Target {
        /// An area or a whole display: a display filter, cropped with `sourceRect` when the region is smaller.
        case region(ScreenRegion, SCDisplay)
        case window(SCWindow)
    }

    private func chooseTarget(_ kind: CaptureKind) async throws -> Target? {
        switch kind {
        case .fullScreen:
            let content = try await ScreenCapturer.content()
            let screen = NSScreen.underMouse
            let display = try ScreenCapturer.display(for: screen, in: content)
            return .region(ScreenRegion(displayID: display.displayID, quartzRect: display.frame, scale: screen?.backingScaleFactor ?? 2), display)
        case .area, .window, .scrolling:
            switch try await OverlayCaptureSession.run(mode: kind == .window ? .window : .area, settings: settings) {
            case .area(_, let region):
                let content = try await ScreenCapturer.content()
                guard let display = content.displays.first(where: { $0.displayID == region.displayID }) else {
                    throw ScreenCapturer.Failure.noDisplay
                }
                return .region(region, display)
            case .window(let window):
                return .window(window)
            case .cancelled:
                return nil
            }
        }
    }

    // MARK: - Recording

    private func begin(_ target: Target) async throws {
        // Every window and app, not only the on-screen ones: the bar and the frame appear after this snapshot,
        // so the whole app is excluded rather than a list of windows.
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        let ourApp = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }

        let filter: SCContentFilter
        let pixelSize: CGSize
        let scale: CGFloat
        let screen: NSScreen?
        switch target {
        case .region(let region, let display):
            filter = SCContentFilter(display: display, excludingApplications: ourApp, exceptingWindows: [])
            pixelSize = region.pixelSize
            scale = region.scale
            screen = NSScreen.screens.first { $0.displayID == region.displayID }
        case .window(let window):
            filter = SCContentFilter(desktopIndependentWindow: window)
            screen = NSScreen.screens.first { $0.displayID == window.displayID(in: content) } ?? .underMouse
            scale = screen?.backingScaleFactor ?? 2
            pixelSize = CGSize(width: window.frame.width * scale, height: window.frame.height * scale)
        }

        let encoding = VideoEncoding.settings(for: pixelSize, scale: scale, quality: settings.videoQuality)
        let configuration = SCStreamConfiguration()
        configuration.width = encoding.width
        configuration.height = encoding.height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(encoding.fps))
        configuration.showsCursor = settings.recordingShowsPointer
        configuration.queueDepth = 5
        configuration.capturesAudio = settings.recordsSystemAudio
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        if case .region(let region, let display) = target, region.quartzRect != display.frame {
            configuration.sourceRect = region.rect(inDisplay: display.frame)
        }
        var microphoneDenied = false
        if settings.recordsMicrophone {
            DiagnosticLog.write("asking for the microphone")
            let allowed = await PermissionService.requestMicrophoneAccess()
            configuration.captureMicrophone = allowed
            microphoneDenied = !allowed
        }

        let url = try TemporaryFiles.newRecordingURL()
        let recorder = ScreenRecorder { [weak self] _ in self?.finish(streamAlreadyStopped: true) }
        try await recorder.start(filter: filter, configuration: configuration, to: url)
        self.recorder = recorder
        self.encoding = encoding
        state = .recording(since: .now)
        DiagnosticLog.write("recording started: \(encoding.width)x\(encoding.height) @\(encoding.fps) fps, "
                            + "mic=\(configuration.captureMicrophone) audio=\(configuration.capturesAudio) → \(url.lastPathComponent)")

        if settings.playsSound { SoundPlayer.playShutter() }
        if microphoneDenied { Toast.show("Microphone is off", symbol: "mic.slash", on: screen) }
        showBar(on: screen)
        if case .region(let region, let display) = target, region.quartzRect != display.frame {
            showFrame(around: region)
        }
    }

    private func finish(streamAlreadyStopped: Bool) {
        guard case .recording(let since) = state, let recorder, let encoding else { return }
        state = .finishing
        hideBarAndFrame()
        Task {
            defer {
                state = .idle
                self.recorder = nil
                self.encoding = nil
            }
            do {
                let url = try await recorder.stop(streamAlreadyStopped: streamAlreadyStopped)
                let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))[.size] as? Int) ?? 0
                DiagnosticLog.write("recording stopped after \(Int(Date.now.timeIntervalSince(since))) s: \(bytes / 1024) KB in \(url.lastPathComponent)")
                onFinished?(url, encoding)
            } catch {
                DiagnosticLog.write("recording failed: \(error)")
                ErrorPresenter.show(title: "Recording failed", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Bar and frame

    private func showBar(on screen: NSScreen?) {
        guard let screen, case .recording(let since) = state else { return }
        let bar = RecordingBarPanel(startedAt: since, onStop: { [weak self] in self?.stop() })
        bar.show(on: screen)
        self.bar = bar
    }

    private func showFrame(around region: ScreenRegion) {
        let frame = RegionFramePanel(region: region)
        frame.orderFrontRegardless()
        self.frame = frame
    }

    private func hideBarAndFrame() {
        bar?.orderOut(nil)
        bar?.contentView = nil
        bar = nil
        frame?.orderOut(nil)
        frame?.contentView = nil
        frame = nil
    }
}

private extension SCWindow {
    /// The display showing most of the window (its centre), from the shareable content.
    func displayID(in content: SCShareableContent) -> CGDirectDisplayID? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return content.displays.first { $0.frame.contains(center) }?.displayID
    }
}
