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
                Ring(accent: accent).position(pulse.point)
            }
        }
        .ignoresSafeArea()
    }
}

/// A dot that fades and a ring that grows and fades, in the accent colour.
private struct Ring: View {
    let accent: Color
    @State private var expanded = false

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(expanded ? 0 : 0.35))
                .frame(width: 22, height: 22)
            Circle()
                .strokeBorder(accent, lineWidth: 3)
                .frame(width: 44, height: 44)
                .scaleEffect(expanded ? 1.25 : 0.35)
                .opacity(expanded ? 0 : 0.95)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { expanded = true }
        }
    }
}
