import AVFoundation
import ClearShotCore
import ScreenCaptureKit
import Synchronization

/// One recording: a ScreenCaptureKit stream writing straight to a file. Start it, stop it, get the file.
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

    private let delegate: RecorderDelegate
    private var stream: SCStream?
    private var output: SCRecordingOutput?
    private(set) var fileURL: URL?

    /// `onStreamStopped` fires on the main actor when the system ends the stream by itself (the recorded window
    /// closed, the display went away).
    init(onStreamStopped: @escaping @MainActor (any Error) -> Void) {
        delegate = RecorderDelegate { error in Task { @MainActor in onStreamStopped(error) } }
    }

    func start(filter: SCContentFilter, configuration: SCStreamConfiguration, to url: URL) async throws {
        let recording = SCRecordingOutputConfiguration()
        recording.outputURL = url
        recording.videoCodecType = .h264
        recording.outputFileType = .mp4
        let output = SCRecordingOutput(configuration: recording, delegate: delegate)
        let stream = SCStream(filter: filter, configuration: configuration, delegate: delegate)
        try stream.addRecordingOutput(output)
        try await stream.startCapture()
        self.stream = stream
        self.output = output
        fileURL = url
    }

    /// Seconds recorded so far.
    var recordedSeconds: Double {
        output.map { CMTimeGetSeconds($0.recordedDuration) } ?? 0
    }

    /// Stops the stream and waits for the file to be complete. `streamAlreadyStopped` skips the stop call when
    /// the system ended the stream itself.
    func stop(streamAlreadyStopped: Bool = false) async throws -> URL {
        guard let stream, let url = fileURL else { throw Failure.notRecording }
        defer {
            self.stream = nil
            output = nil
        }
        if !streamAlreadyStopped {
            try await stream.stopCapture()
        }
        try await delegate.waitUntilFinished(timeout: .seconds(5))
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { throw Failure.noFile }
        return url
    }
}

/// ScreenCaptureKit calls back off the main thread. One place that turns those calls into "the file is done".
nonisolated private final class RecorderDelegate: NSObject, SCStreamDelegate, SCRecordingOutputDelegate, Sendable {
    private struct State {
        var result: Result<Void, any Error>?
        var waiter: CheckedContinuation<Void, any Error>?
    }

    private let state = Mutex(State())
    private let onStreamStopped: @Sendable (any Error) -> Void

    init(onStreamStopped: @escaping @Sendable (any Error) -> Void) {
        self.onStreamStopped = onStreamStopped
    }

    /// Returns once the recording output reports the file finished (or failed). A recording that died before
    /// writing anything never reports, so there is a timeout; the caller then checks for the file itself.
    func waitUntilFinished(timeout: Duration) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await self.waitUntilFinished() }
            group.addTask {
                try await Task.sleep(for: timeout)
                DiagnosticLog.write("recording output did not report finishing within \(timeout)")
            }
            try await group.next()
            group.cancelAll()
        }
    }

    private func waitUntilFinished() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let ready: Result<Void, any Error>? = state.withLock { state in
                if let result = state.result { return result }
                state.waiter = continuation
                return nil
            }
            if let ready { continuation.resume(with: ready) }
        }
    }

    private func finish(_ result: Result<Void, any Error>) {
        let waiter: CheckedContinuation<Void, any Error>? = state.withLock { state in
            guard state.result == nil else { return nil }
            state.result = result
            defer { state.waiter = nil }
            return state.waiter
        }
        waiter?.resume(with: result)
    }

    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        DiagnosticLog.write("recording output started")
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
        DiagnosticLog.write("recording output failed: \(error)")
        finish(.failure(error))
    }

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        DiagnosticLog.write("recording output finished: \(recordingOutput.recordedFileSize / 1024) KB, \(CMTimeGetSeconds(recordingOutput.recordedDuration)) s")
        finish(.success(()))
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        DiagnosticLog.write("recording stream stopped by the system: \(error)")
        onStreamStopped(error)
    }
}
