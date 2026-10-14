import AppKit
import SwiftUI

/// The small floating bar while recording: a red dot, the time, and Stop. It takes no focus and sits at the top
/// centre of the recorded screen. It is put on screen empty and invisible before the recording starts, so the
/// capture filter can leave it out by window; then it gets its content and fades in.
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

    func show(startedAt: Date, on screen: NSScreen, onStop: @escaping () -> Void) {
        let view = FirstMouseHostingView(rootView: RecordingBarView(startedAt: startedAt, onStop: onStop))
        view.sizingOptions = .intrinsicContentSize   // the panel takes SwiftUI's ideal size, so nothing is clipped
        contentView = view
        view.layoutSubtreeIfNeeded()
        let size = view.intrinsicContentSize
        let visible = screen.visibleFrame
        setFrame(CGRect(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 8, width: size.width, height: size.height), display: true)
        orderFrontRegardless()
        animator().alphaValue = 1
    }
}

struct RecordingBarView: View {
    let startedAt: Date
    let onStop: () -> Void

    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .opacity(pulsing ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                Text(Self.label(seconds: context.date.timeIntervalSince(startedAt)))
                    .font(.callout.weight(.medium).monospacedDigit())
            }
            Button(action: onStop) {
                Label("Stop", systemImage: "stop.fill")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.red.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .help("Stop recording")
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .padding(12)   // room for the glass shadow
        .fixedSize()
        .onAppear { pulsing = true }
    }

    /// "0:12", "1:05:03".
    static func label(seconds: TimeInterval) -> String {
        let whole = Int(max(0, seconds))
        return Duration.seconds(whole).formatted(.time(pattern: whole >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }
}
