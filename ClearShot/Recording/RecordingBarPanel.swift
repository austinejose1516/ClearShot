import AppKit
import ClearShotCore
import SwiftUI

/// The time on the recording bar; paused while the recording is.
@Observable
final class RecordingBarModel {
    var clock: RecordingClock

    init(clock: RecordingClock) {
        self.clock = clock
    }
}

/// The small floating bar while recording: a red dot, the time, Pause and Stop. It takes no focus and sits at
/// the bottom centre of the recorded screen, where the toolbar was. It is put on screen empty and invisible
/// before the stream starts, so the capture filter can leave it out by window; then it gets its content and
/// fades in.
final class RecordingBarPanel: NSPanel {
    init() {
        super.init(contentRect: CGRect(x: 0, y: 0, width: 1, height: 1), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        alphaValue = 0
    }

    /// Makes the window exist for the window server (so ScreenCaptureKit can exclude it) without showing anything.
    func reserve() {
        orderFrontRegardless()
    }

    func show(model: RecordingBarModel, on screen: NSScreen, onPause: @escaping () -> Void, onResume: @escaping () -> Void,
              onStop: @escaping () -> Void) {
        let view = FirstMouseHostingView(rootView: RecordingBarView(model: model, onPause: onPause, onResume: onResume, onStop: onStop))
        view.sizingOptions = .intrinsicContentSize   // the panel takes SwiftUI's ideal size, so nothing is clipped
        contentView = view
        view.layoutSubtreeIfNeeded()
        setFrame(ToolbarPanel.bottomCentre(size: view.intrinsicContentSize, on: screen), display: true)
        orderFrontRegardless()
        animator().alphaValue = 1
    }
}

struct RecordingBarView: View {
    let model: RecordingBarModel
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void

    @State private var pulsing = false

    var body: some View {
        let paused = model.clock.isPaused
        HStack(spacing: 8) {
            ZStack {
                if paused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .opacity(pulsing ? 0.35 : 1)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 12)
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                Text(VideoTime.clock(model.clock.elapsed(at: context.date)))
                    .font(.callout.weight(.medium).monospacedDigit())
                    .foregroundStyle(paused ? .secondary : .primary)
                    .frame(minWidth: 52, alignment: .leading)
            }
            .padding(.trailing, 2)
            Button(action: paused ? onResume : onPause) {
                Label(paused ? "Resume" : "Pause", systemImage: paused ? "record.circle" : "pause.fill")
                    .font(.callout.weight(.semibold))
                    .frame(width: 84)   // the same width for both words, so the bar never resizes
                    .padding(.vertical, 5)
                    .background(.primary.opacity(0.08), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(paused ? "Carry on recording" : "Pause the recording")
            Button(action: onStop) {
                Label("Stop", systemImage: "stop.fill")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.red.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Stop and save")
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .padding(12)   // room for the glass shadow
        .fixedSize()
        .animation(.snappy(duration: 0.2), value: paused)
        .onAppear { pulsing = true }
    }
}
