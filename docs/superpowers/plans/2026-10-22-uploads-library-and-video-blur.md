# Uploads Library and Video Blur Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A window that lists the files in the user's R2 bucket (copy link, open, delete), blur boxes in the video editor, a countdown with no flick, and a softer click bubble.

**Architecture:** Pure parts (listing XML → items, kinds, filter and order; blur boxes with hit test, move, resize, clamp) live in `ClearShotCore` with tests. The App adds `R2Uploader.list`, an `Uploads/` folder (window controller, model, view, remote thumbnails), a blur overlay plus an `AVVideoComposition` used by both the player and the exporter, and small changes to the countdown and click panels.

**Tech Stack:** Swift 6, SwiftUI, AppKit, AVFoundation, Core Image, Swift Testing. Build with `make build`; Core tests with `swift test --package-path Packages/ClearShotCore`.

**Spec:** `docs/superpowers/specs/2026-10-22-uploads-library-and-video-blur-design.md`

## Global Constraints

- macOS 26, Swift 6 strict concurrency, `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` in the App target; Core has no default isolation.
- No disk cache for uploads: the thumbnail session has `urlCache = nil` and `requestCachePolicy = .reloadIgnoringLocalCacheData`; thumbnails are dropped when the window closes.
- Listing: `GET /<bucket>?list-type=2&max-keys=1000` plus `continuation-token` when there is one; shown kinds: prefix `images/` → image, `videos/` → video, else by extension `png jpg jpeg gif webp` → image, `mp4 mov m4v` → video, anything else skipped.
- Thumbnails: longest side 512 px.
- Blur boxes: video pixels, origin top-left, smallest side 8 px, clamped to the frame; strengths blur radius `max(10, min(w, h) / 10)`, pixelate scale `max(12, min(w, h) / 12)` (same as `BlurRenderer`).
- Copy: menu item "Uploads…"; window title "Uploads"; filter titles "All", "Images", "Videos"; empty "Nothing uploaded yet"; delete question "Delete <name>?" with "It cannot be undone."; blur switch "Blur", hint "Drag over the part to hide".
- Commit messages follow the log: `core:`, `feat:`, `fix:`, `docs:`; trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Straight to `main`.

## Review Focus

1. A bucket with more than 1000 files: every page is listed (`R2Uploader.list` follows `nextToken` until nil) — pinned by `R2ListingTests.aTruncatedPageCarriesTheNextToken` (Task 1) and the loop in Task 2.
2. A key with no kind (the Connect test `.txt`, a folder marker) never shows and is never deleted — `R2ListingTests.keysWithoutAKindAreSkipped` (Task 1).
3. Deleting a file that is already gone: R2 answers 204 for a missing key, so the card just disappears; a real failure shows an alert and the card stays (Task 2).
4. A blur box dragged past the frame edge stays inside and never flips — `VideoBlurTests.movingKeepsTheBoxInsideTheFrame` and `resizingNeverGoesBelowTheSmallestSide` (Task 3).
5. Done with boxes but no trim must still export (not return the original file) — `VideoWindowController.result()` checks `blurs.isEmpty` too (Task 4), live check.

---

### Task 1: Core — listing, kinds, filter

**Files:**
- Create: `Packages/ClearShotCore/Sources/ClearShotCore/Cloud/R2Listing.swift`
- Modify: `Packages/ClearShotCore/Sources/ClearShotCore/Cloud/R2.swift` (add `listEndpoint`)
- Test: `Packages/ClearShotCore/Tests/ClearShotCoreTests/R2ListingTests.swift`

**Interfaces:**
- Produces:
  - `public enum UploadKind: String, Sendable, CaseIterable { case image, video; public init?(key: String) }`
  - `public struct UploadedItem: Equatable, Sendable, Identifiable { public let key: String; public let size: Int; public let modified: Date; public let kind: UploadKind; public var id: String { key }; public var name: String }`
  - `public enum UploadsFilter: String, CaseIterable, Sendable { case all, images, videos; public var title: String; public func shows(_ kind: UploadKind) -> Bool }`
  - `public enum R2Listing { public struct Page: Equatable, Sendable { public let items: [UploadedItem]; public let nextToken: String? }; public static func parse(_ xml: Data) throws -> Page; public static func shown(_ items: [UploadedItem], filter: UploadsFilter) -> [UploadedItem] }`
  - `extension R2Config { public func listEndpoint(continuationToken: String?) -> URL? }`

- [ ] **Step 1: Write the failing tests** (`R2ListingTests`)

```swift
@Test func kindComesFromTheFolderThenTheExtension() {
    #expect(UploadKind(key: "images/k3x9p2m7qa.png") == .image)
    #expect(UploadKind(key: "videos/k3x9p2m7qa.mp4") == .video)
    #expect(UploadKind(key: "old/shot.JPG") == .image)
    #expect(UploadKind(key: "clip.mov") == .video)
    #expect(UploadKind(key: "clearshot-test-abc.txt") == nil)
    #expect(UploadKind(key: "images/") == nil)
}

@Test func aPageIsParsedNewestFirstWithNameDateAndSize() throws {
    let page = try R2Listing.parse(Data(sample(truncated: false).utf8))
    #expect(page.nextToken == nil)
    #expect(page.items.map(\.key) == ["images/aaaaaaaaaa.png", "videos/bbbbbbbbbb.mp4"])
    #expect(page.items[0].name == "aaaaaaaaaa.png" && page.items[0].size == 1234 && page.items[0].kind == .image)
    #expect(page.items[1].kind == .video)
    #expect(page.items[0].modified == ISO8601DateFormatter().date(from: "2026-10-22T14:03:11Z"))
}

@Test func aTruncatedPageCarriesTheNextToken() throws {
    let page = try R2Listing.parse(Data(sample(truncated: true).utf8))
    #expect(page.nextToken == "tok123")
}

@Test func keysWithoutAKindAreSkipped() throws {
    let page = try R2Listing.parse(Data(sample(truncated: false, extra: "<Contents><Key>clearshot-test-x.txt</Key><LastModified>2026-10-22T14:03:11.000Z</LastModified><Size>5</Size></Contents>").utf8))
    #expect(page.items.count == 2)
}

@Test func brokenXMLIsAnError() {
    #expect(throws: (any Error).self) { try R2Listing.parse(Data("<ListBucketResult><Contents>".utf8)) }
}

@Test func shownItemsFollowTheFilterNewestFirst() {
    let old = UploadedItem(key: "images/a.png", size: 1, modified: Date(timeIntervalSince1970: 100), kind: .image)
    let new = UploadedItem(key: "videos/b.mp4", size: 1, modified: Date(timeIntervalSince1970: 200), kind: .video)
    #expect(R2Listing.shown([old, new], filter: .all).map(\.key) == ["videos/b.mp4", "images/a.png"])
    #expect(R2Listing.shown([old, new], filter: .images).map(\.key) == ["images/a.png"])
    #expect(R2Listing.shown([old, new], filter: .videos).map(\.key) == ["videos/b.mp4"])
    #expect(UploadsFilter.all.title == "All" && UploadsFilter.images.title == "Images" && UploadsFilter.videos.title == "Videos")
}

@Test func listEndpointAsksForUpToAThousandKeysAndFollowsTheToken() {
    let config = R2Config(accountID: "abc123", accessKeyID: "k", bucket: "shots", publicURL: "https://pub-abc.r2.dev")
    #expect(config.listEndpoint(continuationToken: nil)?.absoluteString == "https://abc123.r2.cloudflarestorage.com/shots?list-type=2&max-keys=1000")
    #expect(config.listEndpoint(continuationToken: "a b")?.absoluteString == "https://abc123.r2.cloudflarestorage.com/shots?list-type=2&max-keys=1000&continuation-token=a%20b")
    #expect(R2Config().listEndpoint(continuationToken: nil) == nil)
}
```

`sample(truncated:extra:)` builds a `ListBucketResult` with two `Contents` (`images/aaaaaaaaaa.png`, 1234 bytes, `2026-10-22T14:03:11.000Z`; `videos/bbbbbbbbbb.mp4`), `<IsTruncated>` true/false and `<NextContinuationToken>tok123</NextContinuationToken>` when truncated.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/ClearShotCore --filter R2ListingTests`
Expected: compile failure (types missing).

- [ ] **Step 3: Implement**

`R2Listing.parse` uses Foundation's `XMLParser` with a `nonisolated` delegate collecting `Key`, `LastModified`, `Size` inside `Contents`, plus `NextContinuationToken`. Dates: `ISO8601DateFormatter` with `.withInternetDateTime, .withFractionalSeconds`, falling back to one without fractional seconds. A parse error throws `R2Failure.server("bad listing")`. `shown` filters then sorts by `modified` descending. `listEndpoint` builds with `URLComponents` and `queryItems` in the order `list-type`, `max-keys`, `continuation-token`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --package-path Packages/ClearShotCore --filter "R2ListingTests|R2Tests|SigV4Tests"`
Expected: all pass.

- [ ] **Step 5: Commit** — `core: list the bucket: items, kinds, filter and the listing endpoint`

---

### Task 2: App — the Uploads window

**Files:**
- Modify: `ClearShot/Services/R2Uploader.swift` (add `list()`)
- Modify: `ClearShot/Recording/VideoExporter.swift` (`writer.shouldOptimizeForNetworkUse = true`)
- Create: `ClearShot/Uploads/UploadsModel.swift`, `ClearShot/Uploads/UploadsView.swift`, `ClearShot/Uploads/UploadsWindowController.swift`, `ClearShot/Uploads/RemoteThumbnail.swift`
- Modify: `ClearShot/App/AppDelegate.swift` (`showUploads()`), `ClearShot/App/ClearShotApp.swift` and `ClearShot/App/MenuBarMenu.swift` (`onUploads`), `ClearShot/Settings/CloudSettingsTab.swift` (Show Uploads button)

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `R2Uploader.list() async throws -> [UploadedItem]` — follows pages.
  - `@Observable final class UploadsModel { var items: [UploadedItem]; var filter: UploadsFilter; var isLoading: Bool; var problem: String?; var thumbnails: [String: CGImage]; var shown: [UploadedItem]; func load(); func copyLink(_:); func open(_:); func delete(_:) async; func clear() }` — built with `(settings: AppSettings)`; `uploader` comes from `R2Uploader.fromSettings` on each load, nil → `problem` tells to set up Cloud.
  - `enum RemoteThumbnail { static func load(_ item: UploadedItem, from link: URL) async -> CGImage? }`.
  - `final class UploadsWindowController: NSWindowController, NSWindowDelegate` with `init(settings:)`; `windowWillClose` calls `model.clear()`; showing it calls `model.load()`.
  - `AppDelegate.showUploads()`.

- [ ] **Step 1: `R2Uploader.list()`** — loop `listEndpoint(continuationToken:)`, `send("GET", url)`, `R2Listing.parse`, append, until `nextToken == nil`. Also set `writer.shouldOptimizeForNetworkUse = true` in `VideoExporter.export` right after the writer is made.

- [ ] **Step 2: `RemoteThumbnail`** — a private `URLSession` with `urlCache = nil`, `requestCachePolicy = .reloadIgnoringLocalCacheData`. Images: `CGImageSourceCreateWithData` + `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceCreateThumbnailFromImageAlways`, `kCGImageSourceThumbnailMaxPixelSize: 512`, `kCGImageSourceCreateThumbnailWithTransform`. Videos: `AVAssetImageGenerator(asset: AVURLAsset(url: link))`, `maximumSize` 512×512, `appliesPreferredTrackTransform`, tolerance after 0.5 s, `image(at: .zero)`.

- [ ] **Step 3: `UploadsModel`** — `load()` sets `isLoading`, lists, keeps `items`, then loads thumbnails one by one in a task group of at most 4 at a time, writing into `thumbnails[key]`. `copyLink` uses `settings.cloud.link(name: key)`, `UploadService.copy`, `Toast.show("Link copied")`. `open` uses `NSWorkspace.shared.open`. `delete` calls `uploader.delete(key:)`, removes the item and its thumbnail, logs; a failure sets an alert via `ErrorPresenter.show(title: "Could not delete", message:)`. `clear()` empties `items` and `thumbnails`.

- [ ] **Step 4: `UploadsView`** — top row (`Picker` segmented bound to `model.filter`, `Text("\(count) files")` secondary, Refresh button); `ScrollView` + `LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)])`; `UploadCard` with the thumbnail in a 16:10 rounded box (`.fill`, clipped; a `ProgressView` while nil; a `play.circle.fill` badge for videos), the name (`.callout.monospaced()`), and `date · size` secondary; on hover a glass capsule with three `Button`s (`link`, `safari`, `trash`); `.contextMenu` with the same; `.confirmationDialog("Delete \(name)?", …) { Button("Delete", role: .destructive) } message: { Text("It cannot be undone.") }`. States per spec. Min size 640×420, default 900×600.

- [ ] **Step 5: Window, menu, settings** — `UploadsWindowController` like `SettingsWindowController` (titled, closable, miniaturizable, resizable; `isReleasedWhenClosed = false`; `.themed(settings)`; `window.title = "Uploads"`). `AppDelegate`: `private lazy var uploadsWindow = UploadsWindowController(settings: settings)`; `showUploads()` calls `uploadsWindow.show()` then `WindowPresenter.show`. `MenuBarMenu`: `let onUploads: () -> Void`; item `"Uploads…", "photo.on.rectangle.angled"` after Record, before the divider. `ClearShotApp` passes `onUploads: appDelegate.showUploads`. `CloudSettingsTab`: when connected, a `Button("Show Uploads") { (NSApp.delegate as? AppDelegate)?.showUploads() }` next to Disconnect.

- [ ] **Step 6: Build and check live**

Run: `make build` then `make run`. Open Uploads from the menu: the list appears, the filter works, Copy link copies, Open opens the browser, Delete asks and removes. Close the window: reopen lists again (memory dropped).

- [ ] **Step 7: Commit** — `feat: an Uploads window lists the bucket with copy link, open and delete`

---

### Task 3: Core — blur boxes

**Files:**
- Create: `Packages/ClearShotCore/Sources/ClearShotCore/Video/VideoBlur.swift`
- Test: `Packages/ClearShotCore/Tests/ClearShotCoreTests/VideoBlurTests.swift`

**Interfaces:**
- Produces:
  - `public struct VideoBlur: Equatable, Sendable, Identifiable { public let id: UUID; public var rect: CGRect; public var mode: BlurMode }`
  - `public struct VideoBlurs: Equatable, Sendable { public static let minimumSide: CGFloat = 8; public let frame: CGSize; public private(set) var regions: [VideoBlur]; public init(frame: CGSize); public var isEmpty: Bool; @discardableResult public mutating func add(_ rect: CGRect, mode: BlurMode) -> VideoBlur.ID?; public func region(at point: CGPoint) -> VideoBlur.ID?; public func handle(of id: VideoBlur.ID, at point: CGPoint, tolerance: CGFloat) -> HandleKind?; public mutating func move(_ id: VideoBlur.ID, to rect: CGRect); public mutating func resize(_ id: VideoBlur.ID, dragging handle: HandleKind, to point: CGPoint); public mutating func setMode(_ mode: BlurMode, of id: VideoBlur.ID); public mutating func remove(_ id: VideoBlur.ID); public subscript(id: VideoBlur.ID) -> VideoBlur? }`
  - `move(_:to:)` takes the whole moved rect (the caller adds the drag's translation to the rect it had at the drag's start) and clamps it inside the frame without changing its size.

- [ ] **Step 1: Write the failing tests** (`VideoBlurTests`)

```swift
@Test func addingClampsToTheFrameAndRefusesTinyBoxes() {
    var blurs = VideoBlurs(frame: CGSize(width: 1000, height: 600))
    let id = blurs.add(CGRect(x: -20, y: 550, width: 100, height: 100), mode: .blur)
    #expect(id != nil && blurs.regions.count == 1)
    #expect(blurs.regions[0].rect == CGRect(x: 0, y: 550, width: 80, height: 50))
    #expect(blurs.add(CGRect(x: 10, y: 10, width: 7, height: 50), mode: .blur) == nil)
    #expect(blurs.add(CGRect(x: 10, y: 10, width: 50, height: 7), mode: .blur) == nil)
    #expect(blurs.regions.count == 1 && !blurs.isEmpty)
}

@Test func theNewestBoxIsHitFirst() {
    var blurs = VideoBlurs(frame: CGSize(width: 1000, height: 600))
    let a = blurs.add(CGRect(x: 0, y: 0, width: 200, height: 200), mode: .blur)!
    let b = blurs.add(CGRect(x: 100, y: 100, width: 200, height: 200), mode: .pixelate)!
    #expect(blurs.region(at: CGPoint(x: 150, y: 150)) == b)
    #expect(blurs.region(at: CGPoint(x: 50, y: 50)) == a)
    #expect(blurs.region(at: CGPoint(x: 500, y: 500)) == nil)
}

@Test func cornerHandlesAreFoundWithinTolerance() {
    var blurs = VideoBlurs(frame: CGSize(width: 1000, height: 600))
    let id = blurs.add(CGRect(x: 100, y: 100, width: 200, height: 100), mode: .blur)!
    #expect(blurs.handle(of: id, at: CGPoint(x: 104, y: 97), tolerance: 8) == .topLeft)
    #expect(blurs.handle(of: id, at: CGPoint(x: 300, y: 200), tolerance: 8) == .bottomRight)
    #expect(blurs.handle(of: id, at: CGPoint(x: 200, y: 150), tolerance: 8) == nil)
}

@Test func movingKeepsTheBoxInsideTheFrame() {
    var blurs = VideoBlurs(frame: CGSize(width: 1000, height: 600))
    let id = blurs.add(CGRect(x: 100, y: 100, width: 200, height: 100), mode: .blur)!
    blurs.move(id, to: CGRect(x: 900, y: -50, width: 200, height: 100))
    #expect(blurs[id]?.rect == CGRect(x: 800, y: 0, width: 200, height: 100))
}

@Test func resizingNeverGoesBelowTheSmallestSide() {
    var blurs = VideoBlurs(frame: CGSize(width: 1000, height: 600))
    let id = blurs.add(CGRect(x: 100, y: 100, width: 200, height: 100), mode: .blur)!
    blurs.resize(id, dragging: .bottomRight, to: CGPoint(x: 102, y: 103))
    #expect(blurs[id]?.rect == CGRect(x: 100, y: 100, width: 8, height: 8))
    blurs.resize(id, dragging: .topLeft, to: CGPoint(x: -30, y: -30))
    #expect(blurs[id]?.rect == CGRect(x: 0, y: 0, width: 108, height: 108))
}

@Test func modeAndRemoval() {
    var blurs = VideoBlurs(frame: CGSize(width: 1000, height: 600))
    let id = blurs.add(CGRect(x: 100, y: 100, width: 200, height: 100), mode: .blur)!
    blurs.setMode(.pixelate, of: id)
    #expect(blurs[id]?.mode == .pixelate)
    blurs.remove(id)
    #expect(blurs.isEmpty && blurs[id] == nil)
}
```

- [ ] **Step 2: Run the tests to verify they fail** — `swift test --package-path Packages/ClearShotCore --filter VideoBlurTests`; expected: compile failure.

- [ ] **Step 3: Implement** — `add` standardizes, intersects with the frame, refuses when a side is under `minimumSide`. `region(at:)` walks `regions.reversed()`. `handle(of:at:tolerance:)` checks the four corners (`rect.cornerHandles`, already in `Figures.swift`) within `tolerance`. `resize` uses `rect.resized(dragging:to:)` then clamps to the frame and grows the dragged side to `minimumSide` when needed (anchor side stays). `move` clamps the origin to `0...frame - size`.

- [ ] **Step 4: Run the tests to verify they pass** — same command; expected: pass.

- [ ] **Step 5: Commit** — `core: blur boxes for a recording: add, hit, move, resize inside the frame`

---

### Task 4: App — blur in the video editor

**Files:**
- Modify: `ClearShot/Editor/BlurRegionView.swift` (extract `BlurFilters.hidden(_:area:mode:) -> CIImage?`, used by `BlurRenderer`)
- Create: `ClearShot/Recording/VideoBlurComposition.swift`, `ClearShot/Recording/VideoBlurOverlay.swift`
- Modify: `ClearShot/Recording/VideoExporter.swift` (`blurs:` parameter), `ClearShot/Recording/VideoWindowController.swift`, `ClearShot/Recording/VideoView.swift`, `ClearShot/Recording/VideoEditorStore.swift` (`hasUnsavedTrim` → `hasUnsavedEdits`)

**Interfaces:**
- Consumes: Task 3.
- Produces:
  - `enum BlurFilters { static func hidden(_ input: CIImage, area: CGRect, mode: BlurMode) -> CIImage? }` — `area` in the input's own coordinates (origin bottom-left); the result is cropped to `area`.
  - `nonisolated enum VideoBlurComposition { static func make(for asset: AVAsset, blurs: VideoBlurs) async throws -> AVVideoComposition; static func frame(_ source: CIImage, blurs: VideoBlurs) -> CIImage }` — `frame` flips each box (`y = frame.height - rect.maxY`) and composites `BlurFilters.hidden` over the source.
  - `VideoExporter.export(from:range:encoding:blurs:to:progress:)` — `blurs: VideoBlurs?`; with a non-empty value the reader uses `AVAssetReaderVideoCompositionOutput(videoTracks: [videoTrack], videoSettings: [BGRA])` with `videoComposition = try await VideoBlurComposition.make(for: asset, blurs: blurs)`; otherwise unchanged. `RecordingFinisher.save` passes `nil`.
  - `VideoState`: `var blurs: VideoBlurs`, `var selectedBlur: VideoBlur.ID?`, `var blurToolOn = false`; `VideoCommand`: `.done, .toggleBlurTool, .deleteSelection, .escape`.
  - `VideoView` gets `let videoSize: CGSize` (from `encoding`) and `onBlursChanged: () -> Void` (the controller refreshes the preview); the player is wrapped in a `ZStack` with `VideoBlurOverlay(state:videoSize:onChanged:)` on top.
  - `VideoWindowController.hasUnsavedEdits: Bool` (`!saved && (!range.isWhole || !blurs.isEmpty)`); the store reads it.

- [ ] **Step 1: `BlurFilters`** — move the two `CIFilter` branches of `BlurRenderer.render` into `BlurFilters.hidden`; `BlurRenderer.render` calls it with `input.extent` as the area. Build: unchanged behaviour for screenshots.

- [ ] **Step 2: `VideoBlurComposition`** — `make` uses `AVMutableVideoComposition.videoComposition(with: asset) { request in request.finish(with: frame(request.sourceImage, blurs: blurs), context: nil) }` (the async class method); `frame` as in Interfaces.

- [ ] **Step 3: Exporter and controller** — add `blurs:` to `export`; in `VideoWindowController`: `state.blurs = VideoBlurs(frame: CGSize(width: encoding.width, height: encoding.height))`; `result()` returns `fileURL` only when `range.isWhole && blurs.isEmpty`; `lastExport` keeps `(range, blurs, url)`; `applyPreview()` builds `VideoBlurComposition.make(for: player.currentItem!.asset, blurs:)` and sets `player.currentItem?.videoComposition` (nil when empty) then seeks to `player.currentTime()` with zero tolerance; `perform` handles the three new commands (`toggleBlurTool` flips `blurToolOn` and clears the selection when turning off; `deleteSelection` removes the selected box; `escape` clears the selection and turns the tool off). `VideoWindow.sendEvent` routes key code 51 / 117 to `.deleteSelection` and 53 to `.escape` when the editor's blur tool is on or a box is selected (ask through `onKey: ((UInt16) -> Bool)?`), else `super.sendEvent`.

- [ ] **Step 4: `VideoBlurOverlay`** — `GeometryReader`; `let fitted = AspectFit.rect(for: videoSize, in: bounds)`; scale = `fitted.width / videoSize.width`; draws each region as a rounded rect stroke (`.tint`, 2 pt; selected gets 4 white corner dots 10 pt with a tint border); `allowsHitTesting(state.blurToolOn)`; `DragGesture(minimumDistance: 0)` in `fitted` coordinates: on start, hit test a handle of the selected box, then a box (`region(at:)`), else start a new box; on change: resize / move (`move(id, to: startRect.offsetBy(translation))`) / `pending` rect; on end: `add(pending)` → select it; a click (translation under 3 pt) on empty space clears the selection; then `onChanged()`. Pointer: `.pointerStyle(.crosshair)`-style via `NSCursor.crosshair` on hover while the tool is on and nothing is under the mouse (use `.onContinuousHover`).

- [ ] **Step 5: `VideoView` top bar** — after the length label: a `Toggle("Blur", systemImage: "eye.slash", isOn:)` styled `.button` (bordered, capsule) bound to `state.blurToolOn` through `onCommand(.toggleBlurTool)`; when on and nothing selected: `Text("Drag over the part to hide").foregroundStyle(.secondary)`; when a box is selected: segmented `Picker` Blur / Pixelate (sets the box's mode, then `onBlursChanged`) and a `Button("Remove", systemImage: "trash")` → `onCommand(.deleteSelection)`. The `≈ bytes` and `kept` text are unchanged.

- [ ] **Step 6: Build and check live** — `make run`; record a short clip; Edit; Blur on; draw a box: the player shows it blurred; move/resize; Pixelate; Remove; draw again; Done: the card shows the new first frame, and the file plays blurred in QuickTime. Trim + blur together export once.

- [ ] **Step 7: Commit** — `feat: blur boxes in the video editor, shown live and written on Done`

---

### Task 5: Countdown and click bubble

**Files:**
- Modify: `ClearShot/Recording/CountdownPanel.swift` (`CountdownView`), `ClearShot/Recording/ClickPulsePanel.swift` (`Ring` → `Bubble`)

- [ ] **Step 1: Countdown** — `CountdownView` becomes one `ZStack`: the glass circle (120 pt) stays; inside it `Text("\(model.count)")` with `.contentTransition(.numericText(countsDown: true))` and `.animation(.snappy(duration: 0.35), value: model.count)`; the whole circle gets `.keyframeAnimator(initialValue: 1.0, trigger: model.count) { view, scale in view.scaleEffect(scale) } keyframes: { _ in SpringKeyframe(1.12, duration: 0.12); SpringKeyframe(1.0, duration: 0.25) }`. Remove `.id`, `.transition`.

- [ ] **Step 2: Bubble** — replace `Ring` with `Bubble`: `ZStack` of a filled circle `accent.opacity(0.28)` 52 pt scaling 0.3 → 1.15 and fading to 0, a `strokeBorder(accent.opacity(0.9), lineWidth: 1.5)` circle 52 pt scaling 0.3 → 1 fading to 0, and a 10 pt solid dot fading to 0 over 0.3 s; `.easeOut(duration: 0.6)` on appear. Lifetime stays 650 ms.

- [ ] **Step 3: Build and check live** — `make run`; Record; the numbers roll with no flick; click during the recording: a soft bubble.

- [ ] **Step 4: Commit** — `fix: the countdown rolls its digits without a flick; clicks show a soft bubble`

---

### Task 6: README and release notes draft

**Files:**
- Modify: `README.md` (Share and upload: the Uploads window; recording Edit: blur; menu list; Keyboard: video editor ⌫ / Esc; Project layout: `Uploads/`)

- [ ] **Step 1: Write the docs** — one paragraph each, in the README's voice.
- [ ] **Step 2: Run everything** — `make check` (Core tests + build); expected: pass.
- [ ] **Step 3: Commit** — `docs: the Uploads window and blur in the video editor`
