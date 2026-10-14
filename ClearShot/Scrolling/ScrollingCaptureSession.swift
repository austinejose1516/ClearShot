import AppKit
import ClearShotCore
import ScreenCaptureKit

/// One scrolling capture: frames of the region while the page scrolls (by ClearShot or by hand), stitched into
/// one tall image. Esc cancels; Enter, Done or the end of the page finishes.
@MainActor
final class ScrollingCaptureSession {
    enum Failure: LocalizedError {
        case nothingCaptured

        var errorDescription: String? {
            switch self {
            case .nothingCaptured: "Nothing could be captured."
            }
        }
    }

    struct Result {
        let image: CGImage
        let pages: Int
    }

    /// The scrollbar's strip at the right, left out of the row comparison (its thumb moves with the page).
    private static let scrollbarPoints: CGFloat = 16

    private let region: ScreenRegion
    private let state: ScrollHUDState
    private var stitcher: ScrollStitcher
    private var frames: [CGImage] = []
    private var finishRequested = false
    private var cancelled = false

    private init(region: ScreenRegion, mode: ScrollHUDState.Mode) {
        self.region = region
        state = ScrollHUDState(mode: mode)
        stitcher = ScrollStitcher(frameHeight: Int(region.pixelSize.height))
    }

    /// Nil when cancelled.
    static func run(region: ScreenRegion, mode: ScrollHUDState.Mode) async throws -> Result? {
        try await ScrollingCaptureSession(region: region, mode: mode).start()
    }

    private func start() async throws -> Result? {
        // The frame and the HUD exist before the content snapshot, so the region shots leave them out.
        let frame = RegionFramePanel(region: region)
        frame.orderFrontRegardless()
        let hud = ScrollHUDPanel()
        hud.reserve()
        hud.onFinish = { [weak self] in self?.finishRequested = true }
        hud.onCancel = { [weak self] in self?.cancelled = true }
        defer {
            hud.orderOut(nil)
            hud.contentView = nil
            frame.orderOut(nil)
            frame.contentView = nil
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        frame.reveal()
        hud.show(state: state, near: region)

        let scrollbar = Int(Self.scrollbarPoints * region.scale)
        var (image, rows) = try await shot(content, scrollbar: scrollbar)
        keep(image, stitcher.add(rows))
        var step = ScrollPlanner.stepPoints(regionHeight: region.quartzRect.height)
        var stillFrames = 0
        var lostFrames = 0
        let started = ContinuousClock.now

        loop: while !cancelled, !finishRequested {
            switch state.mode {
            case .automatic:
                ScrollInjector.scrollDown(by: Int(step), at: region.center)
                (image, rows) = try await settledShot(content, scrollbar: scrollbar)
                let result = stitcher.add(rows, expectedShift: Int(step * region.scale))
                keep(image, result)
                switch result {
                case .first, .appended:
                    stillFrames = 0
                    lostFrames = 0
                case .noChange:
                    stillFrames += 1
                    if ScrollPlanner.shouldStop(noChangeInARow: stillFrames) { break loop }
                case .noMatch:
                    lostFrames += 1
                    step = ScrollPlanner.stepAfterNoMatch(step)
                    if ScrollPlanner.shouldStop(noMatchInARow: lostFrames) { break loop }
                }
                if stitcher.totalHeight >= ScrollAssembler.maxHeight { break loop }
            case .manual:
                try await Task.sleep(for: .milliseconds(150))
                (image, rows) = try await shot(content, scrollbar: scrollbar)
                keep(image, stitcher.add(rows))
            }
            state.pages = stitcher.pages
        }
        guard !cancelled else {
            DiagnosticLog.write("scrolling capture cancelled after \(frames.count) frames")
            return nil
        }
        guard let page = ScrollAssembler.assemble(frames: frames, slices: stitcher.slices) else { throw Failure.nothingCaptured }
        DiagnosticLog.write("scrolling capture: \(frames.count) frames, \(stitcher.pages) pages, \(page.width)x\(page.height) px, "
                            + "header \(stitcher.header) footer \(stitcher.footer), in \((ContinuousClock.now - started).formatted(.units(allowed: [.seconds, .milliseconds])))")
        return Result(image: page, pages: stitcher.pages)
    }

    /// Frames are kept only when the stitcher uses them (see `ScrollStitcher`).
    private func keep(_ image: CGImage, _ step: ScrollStitcher.Step) {
        switch step {
        case .first, .appended: frames.append(image)
        case .noChange, .noMatch: break
        }
    }

    private func shot(_ content: SCShareableContent, scrollbar: Int) async throws -> (CGImage, [UInt64]) {
        let image = try await ScreenCapturer.captureRegion(region, in: content)
        return (image, FrameSignature.rows(of: image, ignoringRightPixels: scrollbar))
    }

    /// After a scroll: looks every few milliseconds until two shots in a row are the same (the page has
    /// stopped moving), or gives up waiting after the planner's limit.
    private func settledShot(_ content: SCShareableContent, scrollbar: Int) async throws -> (CGImage, [UInt64]) {
        let started = ContinuousClock.now
        var previous: [UInt64]?
        while true {
            try await Task.sleep(for: ScrollPlanner.settlePoll)
            let (image, rows) = try await shot(content, scrollbar: scrollbar)
            if rows == previous || ContinuousClock.now - started > ScrollPlanner.settleLimit { return (image, rows) }
            previous = rows
        }
    }
}
