import AppKit
import SwiftUI

/// The number shown before a recording starts.
@Observable
final class CountdownModel {
    var count: Int

    init(count: Int) {
        self.count = count
    }
}

/// 3, 2, 1 in a glass circle in the middle of what is being recorded. Clicks go through it. It exists before
/// the capture filter is made, so it is never in the video.
final class CountdownPanel: NSPanel {
    static let size: CGFloat = 180

    let model: CountdownModel

    /// `center` is in AppKit screen coordinates.
    init(center: CGPoint, count: Int) {
        model = CountdownModel(count: count)
        let size = Self.size
        super.init(contentRect: CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        alphaValue = 0
        contentView = NSHostingView(rootView: CountdownView(model: model))
    }

    func reveal() {
        orderFrontRegardless()
        animator().alphaValue = 1
    }
}

/// One glass circle that stays; only the digit rolls, and the circle gives a small bump on each number. The
/// circle is never rebuilt, so it cannot appear again after each number.
private struct CountdownView: View {
    let model: CountdownModel

    var body: some View {
        Text("\(model.count)")
            .font(.system(size: 64, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText(countsDown: true))
            .animation(.snappy(duration: 0.35), value: model.count)
            .frame(width: 120, height: 120)
            .glassEffect(.regular, in: .circle)
            .keyframeAnimator(initialValue: 1.0, trigger: model.count) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                SpringKeyframe(1.12, duration: 0.12)
                SpringKeyframe(1.0, duration: 0.25)
            }
            .frame(width: CountdownPanel.size, height: CountdownPanel.size)
    }
}
