import AppKit
import ClearShotCore
import ScreenCaptureKit

/// What a scrolling capture shows while it runs: how tall the page is so far, whether Auto stopped, and the
/// page in small pieces for the live preview.
@Observable
final class ScrollCaptureState {
    enum Mode {
        case manual, automatic
    }

    let mode: Mode
    var pages = 1
    /// Auto stopped scrolling (the end of the page, or it lost track). Scrolling by hand still adds.
    var reachedEnd = false
    /// Scrolling by hand went further than one picture between two looks: nothing overlaps the last kept
    /// picture. Scrolling back up a little lets it carry on.
    var lostTrack = false
    /// The page so far, top to bottom, scaled down for the preview.
    var preview: [CGImage] = []

    init(mode: Mode) {
        self.mode = mode
    }
}

/// One scrolling capture: pictures of the region while the page scrolls (by ClearShot or by hand), stitched
/// into one tall image. It runs until `finish()` or `cancel()`. The panels ClearShot shows meanwhile must exist
/// before it starts, so its pictures leave them out. A picked window is pictured alone, without what is
/// behind it: through a see-through window the wallpaper stays put while the text moves, and no row would
/// ever match.
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
    /// How often to look while the person scrolls by hand (or after Auto stopped). Often, so a quick flick of
    /// the trackpad still leaves an overlap between two looks.
    private static let manualPoll: Duration = .milliseconds(50)
    /// The preview's pieces are this wide, in pixels (the strip is about 120 points).
    private static let previewWidth = 240

    private let region: ScreenRegion
    private let window: SCWindow?
    private let state: ScrollCaptureState
    private let scrollbar: Int
    private var stitcher: ScrollStitcher
    /// The first picture, until the page first moves.
    private var firstImage: CGImage?
    /// The columns that scroll (see `ScrollBand`), found when the page first moves; nil until then.
    private var band: Range<Int>?
    private var frames: [CGImage] = []
    private var previewCache: [String: CGImage] = [:]
    private var reportedMiss = false
    private var finishRequested = false
    private var cancelled = false

    init(target: RegionPicker.Target, state: ScrollCaptureState) {
        region = target.region
        window = target.window
        self.state = state
        scrollbar = Int(Self.scrollbarPoints * region.scale)
        stitcher = ScrollStitcher(frameHeight: Int(region.pixelSize.height))
    }

    func finish() { finishRequested = true }
    func cancel() { cancelled = true }

    /// Nil when cancelled.
    func run() async throws -> Result? {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        let (first, _) = try await shot(content)
        firstImage = first
        stitcher = ScrollStitcher(frameHeight: first.height)   // a window alone can differ a little from its spot
        state.preview = [Self.scaledDown(first, rows: 0..<first.height, columns: 0..<first.width)].compactMap(\.self)
        var step = ScrollPlanner.stepPoints(regionHeight: region.quartzRect.height)
        var stillFrames = 0
        var lostFrames = 0
        var stepCount = 0
        let started = ContinuousClock.now
        DiagnosticLog.write("scrolling pictures: \(window == nil ? "the region" : "the window alone"), \(first.width)x\(first.height) px")
        if state.mode == .automatic {
            DiagnosticLog.write("auto scroll: may post events=\(CGPreflightPostEventAccess()) accessibility=\(AXIsProcessTrusted()) "
                                + "at \(Int(region.center.x)),\(Int(region.center.y)), step \(Int(step)) pt")
        }

        while !cancelled, !finishRequested {
            if state.mode == .automatic, !state.reachedEnd {
                ScrollInjector.scrollDown(by: Int(step), at: region.center)
                let result = add(try await settledShot(content), expectedShift: Int(step * region.scale))
                stepCount += 1
                DiagnosticLog.write("auto scroll step \(stepCount): \(Self.describe(result)) (asked for \(Int(step)) pt)")
                switch result {
                case .first, .appended:
                    stillFrames = 0
                    lostFrames = 0
                case .noChange:
                    stillFrames += 1
                    if ScrollPlanner.shouldStop(noChangeInARow: stillFrames) { stopAuto("the page stopped moving") }
                case .noMatch:
                    lostFrames += 1
                    step = ScrollPlanner.stepAfterNoMatch(step)
                    if ScrollPlanner.shouldStop(noMatchInARow: lostFrames) { stopAuto("lost track of the page") }
                }
                if stitcher.totalHeight >= ScrollAssembler.maxHeight { stopAuto("the longest page there can be") }
            } else {
                try await Task.sleep(for: Self.manualPoll)
                guard stitcher.totalHeight < ScrollAssembler.maxHeight else { continue }
                _ = add(try await shot(content).image)
            }
            state.pages = stitcher.pages
        }
        guard !cancelled else {
            DiagnosticLog.write("scrolling capture cancelled after \(frames.count) frames")
            return nil
        }
        // The page never moved: the one picture there is.
        guard let band else {
            guard let first = firstImage else { throw Failure.nothingCaptured }
            DiagnosticLog.write("scrolling capture: the page never moved, kept one picture")
            return Result(image: first, pages: 1)
        }
        guard let page = ScrollAssembler.assemble(frames: frames, slices: stitcher.slices, columns: band) else { throw Failure.nothingCaptured }
        DiagnosticLog.write("scrolling capture: \(frames.count) frames, \(stitcher.pages) pages, \(page.width)x\(page.height) px, "
                            + "header \(stitcher.header) footer \(stitcher.footer), in \((ContinuousClock.now - started).formatted(.units(allowed: [.seconds, .milliseconds])))")
        return Result(image: page, pages: stitcher.pages)
    }

    /// One picture for the stitcher. Until the page moves there is nothing to stitch: the first picture waits,
    /// and the first one that differs tells which columns scroll. From then on only those are compared (and
    /// kept), so a sidebar or toolbar that stays put cannot stop the rows from matching.
    private func add(_ image: CGImage, expectedShift: Int? = nil) -> ScrollStitcher.Step {
        if band == nil {
            guard let first = firstImage, let moved = ScrollBand.columns(between: first, and: image) else { return .noChange }
            let found = withoutScrollbar(moved)
            band = found
            DiagnosticLog.write("scrolling part: columns \(found.lowerBound)..<\(found.upperBound) of \(image.width) px")
            keep(first, stitcher.add(FrameSignature.rows(of: first, columns: found)))
        }
        guard let band else { return .noChange }
        let step = stitcher.add(FrameSignature.rows(of: image, columns: band), expectedShift: expectedShift)
        if step == .noMatch, !reportedMiss {
            reportedMiss = true
            reportMiss()
        }
        keep(image, step)
        if state.mode == .manual || state.reachedEnd {
            switch step {
            case .noMatch: state.lostTrack = true
            case .first, .appended: state.lostTrack = false
            case .noChange: break
            }
        }
        return step
    }

    /// The first time a picture does not match the last one kept, the log says how close it came (a see-through
    /// background, or something that keeps changing, shows up as a low share of equal rows).
    private func reportMiss() {
        let closest = stitcher.closest.map { "best: moved \($0.shift) rows with \(Int($0.score * 100)) % of rows equal" }
            ?? "nothing to compare"
        DiagnosticLog.write("scrolling: no overlap with the last picture (\(closest); \(Int((1 - stitcher.tolerance) * 100)) % needed)")
    }

    /// The scrollbar's thumb moves with the page at the right of the part that scrolls; it is left out.
    private func withoutScrollbar(_ columns: Range<Int>) -> Range<Int> {
        columns.count > 2 * scrollbar ? columns.lowerBound..<(columns.upperBound - scrollbar) : columns
    }

    private func stopAuto(_ reason: String) {
        guard !state.reachedEnd else { return }
        state.reachedEnd = true
        DiagnosticLog.write("auto scroll stopped: \(reason)")
    }

    private static func describe(_ step: ScrollStitcher.Step) -> String {
        switch step {
        case .first: "first frame"
        case .appended(let rows): "added \(rows) rows"
        case .noChange: "the page did not move"
        case .noMatch: "no overlap with the last frame"
        }
    }

    /// Frames are kept only when the stitcher uses them (see `ScrollStitcher`); then the preview grows.
    private func keep(_ image: CGImage, _ step: ScrollStitcher.Step) {
        switch step {
        case .first, .appended:
            frames.append(image)
            updatePreview()
        case .noChange, .noMatch:
            break
        }
    }

    /// One small picture per slice of the page. Slices already drawn are reused: only the new strip (and the
    /// footer, which follows the last frame) is scaled down each time.
    private func updatePreview() {
        var cache: [String: CGImage] = [:]
        state.preview = stitcher.slices.compactMap { slice in
            let key = "\(slice.frame):\(slice.rows.lowerBound)-\(slice.rows.upperBound)"
            let small = previewCache[key] ?? Self.scaledDown(frames[slice.frame], rows: slice.rows, columns: band ?? 0..<frames[slice.frame].width)
            cache[key] = small
            return small
        }
        previewCache = cache
    }

    private static func scaledDown(_ frame: CGImage, rows: Range<Int>, columns: Range<Int>) -> CGImage? {
        guard !rows.isEmpty, !columns.isEmpty,
              let part = frame.cropping(to: CGRect(x: columns.lowerBound, y: rows.lowerBound, width: columns.count, height: rows.count))
        else { return nil }
        let width = min(previewWidth, columns.count)
        let height = max(1, Int((Double(rows.count) * Double(width) / Double(columns.count)).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .medium
        context.draw(part, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// A picture of the region, and its whole-row hashes (for telling when the page has stopped moving).
    private func shot(_ content: SCShareableContent) async throws -> (image: CGImage, rows: [UInt64]) {
        let image = if let window {
            try await ScreenCapturer.captureWindow(window, showsCursor: false, includeShadow: false)
        } else {
            try await ScreenCapturer.captureRegion(region, in: content)
        }
        return (image, FrameSignature.rows(of: image, ignoringRightPixels: scrollbar))
    }

    /// After a scroll: looks every few milliseconds until two shots in a row are the same (the page has
    /// stopped moving), or gives up waiting after the planner's limit.
    private func settledShot(_ content: SCShareableContent) async throws -> CGImage {
        let started = ContinuousClock.now
        var previous: [UInt64]?
        while true {
            try await Task.sleep(for: ScrollPlanner.settlePoll)
            let (image, rows) = try await shot(content)
            if rows == previous || ContinuousClock.now - started > ScrollPlanner.settleLimit { return image }
            previous = rows
        }
    }
}
