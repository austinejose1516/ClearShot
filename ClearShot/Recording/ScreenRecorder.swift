import AVFoundation
import ClearShotCore
import ScreenCaptureKit
import Synchronization

/// One recording: a ScreenCaptureKit stream that writes pieces to files, one piece per run between pauses.
/// The stream starts before the first piece (during the countdown), so recording begins without a start-up wait.
final class ScreenRecorder {
    enum Failure: LocalizedError {
        case notRecording
        case noFile

        var errorDescription: String? {
            switch self {
            case .notRecording: "Nothing is being recorded."
            case .noFile: "The recording did not produce a file."
            }
        }
    }

    private let streamDelegate: StreamDelegate
    /// Frames the stream hands over between pieces have nowhere else to go; this takes and drops them.
    private let idleOutput = IdleOutput()
    private var stream: SCStream?
    private var piece: (output: SCRecordingOutput, delegate: PieceDelegate, url: URL)?
    /// Finished pieces, in order.
    private(set) var pieces: [URL] = []

    /// `onStreamStopped` fires on the main actor when the system ends the stream by itself (the display went
    /// away, the permission was taken back).
    init(onStreamStopped: @escaping @MainActor (any Error) -> Void) {
        streamDelegate = StreamDelegate { error in Task { @MainActor in onStreamStopped(error) } }
    }

    var isWritingPiece: Bool { piece != nil }

    func startStream(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws {
        let stream = SCStream(filter: filter, configuration: configuration, delegate: streamDelegate)
        try stream.addStreamOutput(idleOutput, type: .screen, sampleHandlerQueue: idleOutput.queue)
        try await stream.startCapture()
        self.stream = stream
    }

    /// Starts writing a new piece to `url`. Returns once the first frame is in the file (or after a short wait).
    func beginPiece(to url: URL) async throws {
        guard let stream, piece == nil else { throw Failure.notRecording }
        let recording = SCRecordingOutputConfiguration()
        recording.outputURL = url
        recording.videoCodecType = .h264
        recording.outputFileType = .mp4
        let delegate = PieceDelegate()
        let output = SCRecordingOutput(configuration: recording, delegate: delegate)
        try stream.addRecordingOutput(output)
        piece = (output, delegate, url)
        await delegate.waitUntilStarted(timeout: .seconds(2))
    }

    /// Ends the current piece and waits for its file to be complete.
    func endPiece() async throws {
        guard let stream, let piece else { return }
        self.piece = nil
        try stream.removeRecordingOutput(piece.output)
        try await piece.delegate.waitUntilFinished(timeout: .seconds(5))
        if FileManager.default.fileExists(atPath: piece.url.path(percentEncoded: false)) {
            pieces.append(piece.url)
        }
    }

    /// Ends the last piece, stops the stream and returns every piece. `streamAlreadyStopped` skips the stop call
    /// when the system ended the stream itself.
    func stop(streamAlreadyStopped: Bool = false) async throws -> [URL] {
        guard let stream else { throw Failure.notRecording }
        defer { self.stream = nil }
        if let piece {
            self.piece = nil
            if !streamAlreadyStopped { try? stream.removeRecordingOutput(piece.output) }
            try? await piece.delegate.waitUntilFinished(timeout: .seconds(5))
            if FileManager.default.fileExists(atPath: piece.url.path(percentEncoded: false)) { pieces.append(piece.url) }
        }
        if !streamAlreadyStopped { try? await stream.stopCapture() }
        guard !pieces.isEmpty else { throw Failure.noFile }
        return pieces
    }

    /// Stops everything and deletes what was written (Cancel during the countdown, or a failed start).
    func discard() async {
        let urls = pieces + [piece?.url].compactMap(\.self)
        if let stream {
            if let piece { try? stream.removeRecordingOutput(piece.output) }
            try? await stream.stopCapture()
        }
        stream = nil
        piece = nil
        pieces = []
        for url in urls { try? FileManager.default.removeItem(at: url) }
    }
}

/// Takes the stream's frames and drops them; the recording outputs get their own copy.
nonisolated private final class IdleOutput: NSObject, SCStreamOutput, Sendable {
    let queue = DispatchQueue(label: "com.austinejose.clearshot.recording.idle")

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {}
}

/// Tells the recorder when the system ends the stream on its own.
nonisolated private final class StreamDelegate: NSObject, SCStreamDelegate, Sendable {
    private let onStreamStopped: @Sendable (any Error) -> Void

    init(onStreamStopped: @escaping @Sendable (any Error) -> Void) {
        self.onStreamStopped = onStreamStopped
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        DiagnosticLog.write("recording stream stopped by the system: \(error)")
        onStreamStopped(error)
    }
}

/// ScreenCaptureKit calls back off the main thread. One per piece: turns those calls into "started" and
/// "the file is done".
nonisolated private final class PieceDelegate: NSObject, SCRecordingOutputDelegate, Sendable {
    private struct State {
        var started = false
        var startWaiter: CheckedContinuation<Void, Never>?
        var result: Result<Void, any Error>?
        var finishWaiter: CheckedContinuation<Void, any Error>?
    }

    private let state = Mutex(State())

    /// Returns once the first frame is written, or after `timeout` (a still screen may not send a frame at once).
    func waitUntilStarted(timeout: Duration) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.waitUntilStarted() }
            group.addTask { try? await Task.sleep(for: timeout) }
            await group.next()
            group.cancelAll()
            self.markStarted()   // releases the first task if the timeout won
        }
    }

    private func waitUntilStarted() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let ready: Bool = state.withLock { state in
                if state.started { return true }
                state.startWaiter = continuation
                return false
            }
            if ready { continuation.resume() }
        }
    }

    private func markStarted() {
        let waiter: CheckedContinuation<Void, Never>? = state.withLock { state in
            state.started = true
            defer { state.startWaiter = nil }
            return state.startWaiter
        }
        waiter?.resume()
    }

    /// Returns once the output reports the file finished (or failed). A piece that died before writing anything
    /// never reports, so there is a timeout; the caller then checks for the file itself.
    func waitUntilFinished(timeout: Duration) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await self.waitUntilFinished() }
            group.addTask {
                try await Task.sleep(for: timeout)
                DiagnosticLog.write("recording piece did not report finishing within \(timeout)")
            }
            try await group.next()
            group.cancelAll()
            self.finish(.success(()))   // releases the first task if the timeout won
        }
    }

    private func waitUntilFinished() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let ready: Result<Void, any Error>? = state.withLock { state in
                if let result = state.result { return result }
                state.finishWaiter = continuation
                return nil
            }
            if let ready { continuation.resume(with: ready) }
        }
    }

    private func finish(_ result: Result<Void, any Error>) {
        let waiter: CheckedContinuation<Void, any Error>? = state.withLock { state in
            guard state.result == nil else { return nil }
            state.result = result
            defer { state.finishWaiter = nil }
            return state.finishWaiter
        }
        waiter?.resume(with: result)
    }

    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        DiagnosticLog.write("recording piece started")
        markStarted()
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
        DiagnosticLog.write("recording piece failed: \(error)")
        markStarted()
        finish(.failure(error))
    }

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        DiagnosticLog.write("recording piece finished: \(recordingOutput.recordedFileSize / 1024) KB, \(CMTimeGetSeconds(recordingOutput.recordedDuration)) s")
        finish(.success(()))
    }
}
