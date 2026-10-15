import AppKit
import AVFoundation
import ClearShotCore
import ScreenCaptureKit
import SwiftUI

/// Runs one screen recording at a time: pick what to record, get ready in the toolbar, count down, record with
/// pauses, then save it to the folder and show a card, like a screenshot.
@Observable
final class RecordingCoordinator {
    enum State: Equatable {
        case idle
        /// The area or window picker is up.
        case choosing
        /// The toolbar is up: options, Change Area, Record.
        case ready
        case countdown
        case recording
        case paused
    }

    static let countdownFrom = 3

    private(set) var state: State = .idle

    /// Recording or paused: the menu offers Pause or Resume and Stop, and the menu bar icon changes.
    var isRecording: Bool { state == .recording || state == .paused }

    private let settings: AppSettings
    private let quickAccess: QuickAccessController
    private let onPermissionMissing: () -> Void

    private var kind: CaptureKind = .area
    private var region: ScreenRegion?
    private let toolbarModel = RecordingToolbarModel()
    private var toolbar: ToolbarPanel?
    private var frame: RegionFramePanel?
    private var countdown: CountdownPanel?
    private var pulses: ClickPulsePanel?
    private var bar: RecordingBarPanel?
    private var barModel: RecordingBarModel?
    private var recorder: ScreenRecorder?
    private var encoding: VideoEncoding.Settings?
    private var startedAt: Date?
    private var countdownTask: Task<Void, Never>?
    /// Pause and Resume each wait for the one before (and Stop for both), so pieces never overlap.
    private var lastStep: Task<Void, Never>?

    init(settings: AppSettings, quickAccess: QuickAccessController, onPermissionMissing: @escaping () -> Void) {
        self.settings = settings
        self.quickAccess = quickAccess
        self.onPermissionMissing = onPermissionMissing
    }

    /// A record hotkey: pick `kind`, start the one that is ready, or stop the one running.
    func toggle(_ kind: CaptureKind) {
        switch state {
        case .idle: start(kind)
        case .ready: record()
        case .recording, .paused: stop()
        case .choosing, .countdown: break
        }
    }

    func start(_ kind: CaptureKind) {
        guard PermissionService.hasScreenRecordingAccess else {
            DiagnosticLog.write("record(\(kind.rawValue)) blocked: no Screen Recording access")
            onPermissionMissing()
            return
        }
        guard state == .idle else { return }
        self.kind = kind
        DiagnosticLog.write("record(\(kind.rawValue)) choosing")
        choose(keeping: nil)
    }

    /// Closes the toolbar (or stops the countdown) without recording.
    func cancel() {
        guard state == .ready || state == .countdown else { return }
        countdownTask?.cancel()
        countdownTask = nil
        tearDownPanels()
        state = .idle
        DiagnosticLog.write("recording cancelled before it started")
    }

    func record() {
        guard state == .ready, let region else { return }
        state = .countdown
        toolbarModel.countdown = Self.countdownFrom
        countdownTask = Task { await countDownAndStart(region) }
    }

    /// The pause hotkey: pause a running recording, resume a paused one.
    func togglePause() {
        switch state {
        case .recording: pause()
        case .paused: resume()
        default: break
        }
    }

    func pause() {
        guard state == .recording, let recorder else { return }
        state = .paused
        barModel?.clock.pause(at: .now)
        DiagnosticLog.write("recording paused")
        step { try await recorder.endPiece() }
    }

    func resume() {
        guard state == .paused, let recorder else { return }
        state = .recording
        barModel?.clock.resume(at: .now)
        DiagnosticLog.write("recording resumed")
        step { [weak self] in
            do {
                try await recorder.beginPiece(to: TemporaryFiles.newPieceURL())
            } catch {
                DiagnosticLog.write("could not resume: \(error)")
                ErrorPresenter.show(title: "Could not resume the recording", message: "What was recorded so far is saved.\n\n\(error.localizedDescription)")
                self?.stop()
            }
        }
    }

    func stop() {
        finish(streamAlreadyStopped: false)
    }

    // MARK: - Choosing

    /// Opens the picker. Cancelling it goes back to `previous` (Change Area), or ends everything when there is none.
    private func choose(keeping previous: ScreenRegion?) {
        state = .choosing
        Task {
            do {
                guard let picked = try await RegionPicker.pick(kind, settings: settings)?.region ?? previous else {
                    DiagnosticLog.write("record(\(kind.rawValue)) cancelled")
                    state = .idle
                    return
                }
                region = picked
                showToolbar(for: picked)
            } catch {
                tearDownPanels()
                state = .idle
                DiagnosticLog.write("record(\(kind.rawValue)) could not pick: \(error)")
                ErrorPresenter.show(title: "Could not start recording", message: error.localizedDescription)
            }
        }
    }

    // MARK: - The toolbar

    private func showToolbar(for region: ScreenRegion) {
        guard let screen = region.screen else {
            state = .idle
            return
        }
        state = .ready
        if !region.coversWholeScreen {
            let frame = RegionFramePanel(region: region)
            frame.orderFrontRegardless()
            frame.reveal()
            self.frame = frame
        }
        toolbarModel.countdown = nil
        toolbarModel.microphones = Microphone.all()
        checkMicrophone(asking: settings.recordsMicrophone)

        let toolbar = ToolbarPanel()
        toolbar.onReturn = { [weak self] in self?.record() }
        toolbar.onEscape = { [weak self] in self?.cancel() }
        toolbar.show(RecordingToolbarView(
            model: toolbarModel,
            changeTitle: ToolbarChangeButton.title(for: kind),
            onCancel: { [weak self] in self?.cancel() },
            onChange: { [weak self] in self?.changeTarget() },
            onRecord: { [weak self] in self?.record() },
            onMicrophoneTurnedOn: { [weak self] in self?.checkMicrophone(asking: true, openSettingsIfDenied: true) })
            .themed(settings), on: screen)
        self.toolbar = toolbar
        DiagnosticLog.write("record(\(kind.rawValue)) ready: \(Int(region.quartzRect.width))x\(Int(region.quartzRect.height)) pt")
    }

    private func changeTarget() {
        guard state == .ready else { return }
        tearDownPanels()
        choose(keeping: region)
    }

    /// Asks for the microphone the first time it is wanted (the system prompt), so it never interrupts the
    /// countdown. Refused, the Mic switch shows off and explains.
    private func checkMicrophone(asking: Bool, openSettingsIfDenied: Bool = false) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            toolbarModel.microphoneAllowed = true
        case .notDetermined:
            toolbarModel.microphoneAllowed = true
            guard asking else { return }
            DiagnosticLog.write("asking for the microphone")
            Task { toolbarModel.microphoneAllowed = await PermissionService.requestMicrophoneAccess() }
        default:
            toolbarModel.microphoneAllowed = false
            if openSettingsIfDenied { PermissionService.openMicrophoneSettings() }
        }
    }

    // MARK: - Countdown and start

    /// The stream starts while the numbers count down, so the first piece begins the moment they end.
    private func countDownAndStart(_ region: ScreenRegion) async {
        let screen = region.screen
        // Everything ClearShot shows during the recording exists before the capture filter is made, so the
        // filter can leave it out by window. The click rings are the one thing left in.
        let bar = RecordingBarPanel()
        bar.reserve()
        self.bar = bar
        let countdown = CountdownPanel(center: CGPoint(x: region.appKitRect.midX, y: region.appKitRect.midY), count: Self.countdownFrom)
        countdown.reveal()
        self.countdown = countdown
        if settings.recordingShowsClicks, let screen {
            let pulses = ClickPulsePanel(screen: screen, accent: Color(settings.accent.color))
            pulses.start()
            self.pulses = pulses
        }
        let recorder = ScreenRecorder { [weak self] _ in self?.streamStoppedBySystem() }
        do {
            async let streamReady = startStream(region, with: recorder)
            for count in (1...Self.countdownFrom).reversed() {
                toolbarModel.countdown = count
                countdown.model.count = count
                try await Task.sleep(for: .seconds(1))
            }
            let encoding = try await streamReady
            try Task.checkCancellation()
            try await recorder.beginPiece(to: TemporaryFiles.newPieceURL())
            try Task.checkCancellation()
            began(recorder: recorder, encoding: encoding, on: screen)
        } catch {
            await recorder.discard()
            guard !(error is CancellationError) else { return }   // cancel() already closed everything
            tearDownPanels()
            state = .idle
            DiagnosticLog.write("recording failed to start: \(error)")
            ErrorPresenter.show(title: "Could not start recording", message: error.localizedDescription)
        }
    }

    private func startStream(_ region: ScreenRegion, with recorder: ScreenRecorder) async throws -> VideoEncoding.Settings {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first(where: { $0.displayID == region.displayID }) else {
            throw ScreenCapturer.Failure.noDisplay
        }
        let pulsesID = pulses.map { CGWindowID($0.windowNumber) }
        let leftOut = content.windows.filter {
            $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier && $0.windowID != pulsesID
        }
        DiagnosticLog.write("recording leaves out \(leftOut.count) ClearShot windows\(pulsesID == nil ? "" : ", keeps the click rings")")
        let filter = SCContentFilter(display: display, excludingWindows: leftOut)

        let encoding = VideoEncoding.settings(for: region.pixelSize, scale: region.scale, quality: settings.videoQuality)
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
        if region.quartzRect != display.frame {
            configuration.sourceRect = region.rect(inDisplay: display.frame)
        }
        configuration.captureMicrophone = settings.recordsMicrophone && AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        if configuration.captureMicrophone, let id = settings.microphoneID, Microphone.all().contains(where: { $0.id == id }) {
            configuration.microphoneCaptureDeviceID = id
        }
        try await recorder.startStream(filter: filter, configuration: configuration)
        DiagnosticLog.write("recording stream started: \(encoding.width)x\(encoding.height) @\(encoding.fps) fps, "
                            + "mic=\(configuration.captureMicrophone) audio=\(configuration.capturesAudio) "
                            + "pointer=\(configuration.showsCursor) clicks=\(pulsesID != nil)")
        return encoding
    }

    /// The first piece is being written: the sound, the bar, and the toolbar goes (keys return to the app the
    /// user was in).
    private func began(recorder: ScreenRecorder, encoding: VideoEncoding.Settings, on screen: NSScreen?) {
        self.recorder = recorder
        self.encoding = encoding
        let now = Date.now
        startedAt = now
        state = .recording
        countdownTask = nil
        if settings.playsSound { SoundPlayer.playRecordStart() }
        toolbar?.orderOut(nil)
        toolbar?.contentView = nil
        toolbar = nil
        countdown?.orderOut(nil)
        countdown = nil
        let model = RecordingBarModel(clock: RecordingClock(startedAt: now))
        barModel = model
        if let screen {
            bar?.show(model: model, on: screen,
                      onPause: { [weak self] in self?.pause() },
                      onResume: { [weak self] in self?.resume() },
                      onStop: { [weak self] in self?.stop() })
        }
        DiagnosticLog.write("recording started")
    }

    private func step(_ work: @escaping () async throws -> Void) {
        let previous = lastStep
        lastStep = Task {
            await previous?.value
            do {
                try await work()
            } catch {
                DiagnosticLog.write("recording step failed: \(error)")
            }
        }
    }

    // MARK: - Stop and save

    private func streamStoppedBySystem() {
        if isRecording { finish(streamAlreadyStopped: true) }
    }

    /// Everything is handed to a task, and the coordinator is free for the next recording at once; the card
    /// shows the saving.
    private func finish(streamAlreadyStopped: Bool) {
        guard isRecording, let recorder, let encoding, let startedAt, let region else { return }
        if settings.playsSound { SoundPlayer.playRecordStop() }
        let screen = region.screen
        let kind = kind
        let previous = lastStep
        tearDownPanels()
        self.recorder = nil
        self.encoding = nil
        self.startedAt = nil
        lastStep = nil
        state = .idle
        Task {
            await previous?.value
            do {
                let pieces = try await recorder.stop(streamAlreadyStopped: streamAlreadyStopped)
                DiagnosticLog.write("recording stopped: \(pieces.count) piece(s)")
                await save(pieces, encoding: encoding, kind: kind, startedAt: startedAt, on: screen)
            } catch {
                DiagnosticLog.write("recording failed: \(error)")
                ErrorPresenter.show(title: "Recording failed", message: error.localizedDescription)
            }
        }
    }

    /// The card first (with the first frame and a saving ring), then the pieces become one small file in the
    /// save folder, like a screenshot. The clipboard gets the file when that setting is on.
    private func save(_ pieces: [URL], encoding: VideoEncoding.Settings, kind: CaptureKind, startedAt: Date, on screen: NSScreen?) async {
        let duration = await RecordingFinisher.duration(of: pieces)
        let poster = await RecordingFinisher.poster(of: pieces[0]) ?? Self.blankPoster(encoding)
        let capture = Capture(kind: kind, image: poster, createdAt: startedAt, video: Capture.Video(duration: duration, encoding: encoding))
        let id = capture.id
        let quickAccess = quickAccess
        quickAccess.show(capture, on: screen)
        quickAccess.setSaveProgress(id, 0)

        let destination: URL
        do {
            destination = try FileSaver.reserveURL(fileExtension: "mp4", in: settings.saveFolder, date: startedAt)
        } catch {
            quickAccess.close(id: id)
            ErrorPresenter.show(title: "Could not save the recording", message: error.localizedDescription)
            return
        }
        let started = ContinuousClock.now
        do {
            _ = try await Task.detached(priority: .userInitiated) {
                try await RecordingFinisher.save(pieces: pieces, encoding: encoding, to: destination) { fraction in
                    Task { @MainActor in quickAccess.setSaveProgress(id, fraction) }
                }
            }.value
            let bytes = (try? FileManager.default.attributesOfItem(atPath: destination.path(percentEncoded: false))[.size] as? Int) ?? 0
            DiagnosticLog.write("recording saved: \(VideoTime.length(duration)), \(bytes / 1024) KB in "
                                + "\((ContinuousClock.now - started).formatted(.units(allowed: [.seconds, .milliseconds]))) → \(destination.path(percentEncoded: false))")
            for piece in pieces { try? FileManager.default.removeItem(at: piece) }
        } catch {
            // One piece can still be kept as it is: big, but nothing is lost.
            guard pieces.count == 1, (try? FileManager.default.moveItem(at: pieces[0], to: destination)) != nil else {
                quickAccess.close(id: id)
                DiagnosticLog.write("recording could not be saved: \(error)")
                ErrorPresenter.show(title: "Could not save the recording", message: error.localizedDescription)
                return
            }
            DiagnosticLog.write("recording saved without compressing (\(error))")
        }
        quickAccess.fileWritten(id, at: destination)
        if settings.copiesToClipboard { ClipboardService.copy(fileURL: destination) }
    }

    /// A black picture the size of the video, for the rare recording whose first frame cannot be read.
    private static func blankPoster(_ encoding: VideoEncoding.Settings) -> CGImage {
        let context = CGContext(data: nil, width: max(2, encoding.width / 4), height: max(2, encoding.height / 4), bitsPerComponent: 8,
                                bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
        return context.makeImage()!
    }

    // MARK: - Panels

    private func tearDownPanels() {
        for panel in [toolbar, frame, countdown, bar] as [NSPanel?] {
            panel?.orderOut(nil)
            panel?.contentView = nil
        }
        pulses?.stop()
        toolbar = nil
        frame = nil
        countdown = nil
        bar = nil
        pulses = nil
        barModel = nil
    }
}
