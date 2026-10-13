import AppKit
import SwiftUI

/// A short message in a glass capsule near the top of the screen under the mouse ("Link copied"). It takes no
/// focus and fades out by itself.
enum Toast {
    private static var panel: NSPanel?
    private static var hide: Task<Void, Never>?

    static func show(_ text: String, symbol: String = "checkmark.circle.fill", on screen: NSScreen? = .underMouse) {
        hide?.cancel()
        panel?.orderOut(nil)
        guard let screen else { return }
        let view = NSHostingView(rootView: ToastView(text: text, symbol: symbol))
        let size = view.fittingSize
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = view
        let visible = screen.visibleFrame
        panel.setFrameOrigin(CGPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 48))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.animator().alphaValue = 1
        self.panel = panel
        hide = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            }, completionHandler: {
                MainActor.assumeIsolated {
                    panel.orderOut(nil)
                    if Self.panel === panel { Self.panel = nil }
                }
            })
        }
    }
}

private struct ToastView: View {
    let text: String
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.callout.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
            .padding(12)   // room for the glass shadow
    }
}
