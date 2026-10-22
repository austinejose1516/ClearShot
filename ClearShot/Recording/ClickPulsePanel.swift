import AppKit
import SwiftUI

/// The rings on screen right now.
@Observable
final class ClickPulseModel {
    struct Pulse: Identifiable {
        let id = UUID()
        /// In the panel's SwiftUI coordinates (origin top-left).
        let point: CGPoint
    }

    var pulses: [Pulse] = []
}

/// A click-through layer over the recorded screen that draws a ring where you click. Unlike ClearShot's other
/// panels it is left in the capture, so the rings are in the video. Clicks in other apps only: clicks on the
/// recording bar are not shown.
final class ClickPulsePanel: NSPanel {
    static let lifetime: Duration = .milliseconds(650)

    private let model = ClickPulseModel()
    private var monitor: Any?

    init(screen: NSScreen, accent: Color) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = NSHostingView(rootView: ClickPulseView(model: model, accent: accent))
    }

    /// Orders the panel in (so the capture filter sees it) and starts listening for clicks. Mouse events from
    /// other apps need no permission.
    func start() {
        orderFrontRegardless()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.pulse(at: NSEvent.mouseLocation) }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        orderOut(nil)
        contentView = nil
    }

    /// `location` is in AppKit screen coordinates.
    private func pulse(at location: CGPoint) {
        guard frame.contains(location) else { return }
        let pulse = ClickPulseModel.Pulse(point: CGPoint(x: location.x - frame.minX, y: frame.maxY - location.y))
        model.pulses.append(pulse)
        Task { [model] in
            try? await Task.sleep(for: Self.lifetime)
            model.pulses.removeAll { $0.id == pulse.id }
        }
    }
}

struct ClickPulseView: View {
    let model: ClickPulseModel
    let accent: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(model.pulses) { pulse in
                Bubble(accent: accent).position(pulse.point)
            }
        }
        .ignoresSafeArea()
    }
}

/// A soft bubble in the accent colour: a filled circle that grows and fades, with a thin edge and a small
/// centre dot that goes first.
private struct Bubble: View {
    static let size: CGFloat = 52

    let accent: Color
    @State private var expanded = false

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.28))
                .frame(width: Self.size, height: Self.size)
                .scaleEffect(expanded ? 1.15 : 0.3)
                .opacity(expanded ? 0 : 1)
            Circle()
                .strokeBorder(accent.opacity(0.9), lineWidth: 1.5)
                .frame(width: Self.size, height: Self.size)
                .scaleEffect(expanded ? 1 : 0.3)
                .opacity(expanded ? 0 : 1)
            Circle()
                .fill(accent)
                .frame(width: 10, height: 10)
                .opacity(expanded ? 0 : 0.9)
                .animation(.easeOut(duration: 0.3), value: expanded)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { expanded = true }
        }
    }
}
