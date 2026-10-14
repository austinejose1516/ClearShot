import AppKit
import ClearShotCore
import SwiftUI

/// What the HUD shows while a scrolling capture runs.
@Observable
final class ScrollHUDState {
    enum Mode {
        case automatic, manual
    }

    let mode: Mode
    var pages = 1

    init(mode: Mode) {
        self.mode = mode
    }
}

/// A glass pill next to the region: what is happening, Done and Cancel. It becomes key (without activating
/// the app) so Enter and Esc work; the page under the mouse still gets the scroll events.
final class ScrollHUDPanel: NSPanel {
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?

    init() {
        super.init(contentRect: CGRect(x: 0, y: 0, width: 1, height: 1), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        alphaValue = 0
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onCancel?()            // Esc
        case 36, 76: onFinish?()        // Return, Enter
        default: super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    /// Exists for the window server (so the capture leaves it out) but shows nothing yet.
    func reserve() {
        orderFrontRegardless()
    }

    /// Fills the pill and puts it under the region (above it when there is no room), then fades it in.
    func show(state: ScrollHUDState, near region: ScreenRegion) {
        let view = FirstMouseHostingView(rootView: ScrollHUDView(
            state: state,
            onFinish: { [weak self] in self?.onFinish?() },
            onCancel: { [weak self] in self?.onCancel?() }))
        view.sizingOptions = .intrinsicContentSize
        contentView = view
        view.layoutSubtreeIfNeeded()
        let size = view.intrinsicContentSize
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let quartz = region.quartzRect
        let screen = NSScreen.screens.first { $0.displayID == region.displayID } ?? .main
        let visibleTop = screen.map { primaryHeight - $0.visibleFrame.maxY } ?? 0          // in Quartz
        let visibleBottom = screen.map { primaryHeight - $0.visibleFrame.minY } ?? primaryHeight
        var top = quartz.maxY + 8
        if top + size.height > visibleBottom { top = quartz.minY - size.height - 8 }
        if top < visibleTop { top = quartz.maxY - size.height - 8 }
        let x = min(max(quartz.midX - size.width / 2, 0), (screen?.frame.maxX ?? quartz.maxX) - size.width)
        setFrame(CGRect(x: x, y: primaryHeight - top - size.height, width: size.width, height: size.height), display: true)
        makeKeyAndOrderFront(nil)
        animator().alphaValue = 1
    }
}

struct ScrollHUDView: View {
    let state: ScrollHUDState
    let onFinish: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state.mode == .automatic ? "arrow.down.to.line" : "hand.draw")
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.mode == .automatic ? "Scrolling the page…" : "Scroll down, then press Enter")
                    .font(.callout.weight(.semibold))
                Text("\(state.pages) \(state.pages == 1 ? "page" : "pages") so far · Enter to finish · Esc to cancel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Button("Done", action: onFinish)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            Button("Cancel", action: onCancel)
                .buttonBorderShape(.capsule)
        }
        .controlSize(.small)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .padding(12)   // room for the glass shadow
        .fixedSize()
    }
}
