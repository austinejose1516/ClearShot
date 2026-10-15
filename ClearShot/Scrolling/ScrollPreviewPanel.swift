import AppKit
import ClearShotCore
import SwiftUI

/// A glass strip beside the area that shows the tall picture growing, newest part at the bottom. Clicks and
/// scrolls go through it. It exists before the capture's pictures are taken, so it is never in them.
final class ScrollPreviewPanel: NSPanel {
    static let width: CGFloat = 120

    init(state: ScrollCaptureState, beside region: ScreenRegion) {
        let visible = region.screen?.visibleFrame ?? region.appKitRect
        let frame = SidePanelLayout.frame(width: Self.width, beside: region.appKitRect, in: visible)
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        alphaValue = 0
        contentView = NSHostingView(rootView: ScrollPreviewView(state: state))
    }

    func reveal() {
        orderFrontRegardless()
        animator().alphaValue = 1
    }
}

private struct ScrollPreviewView: View {
    let state: ScrollCaptureState

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ForEach(Array(state.preview.enumerated()), id: \.offset) { _, part in
                    Image(decorative: part, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .frame(width: proxy.size.width)
            .fixedSize(horizontal: false, vertical: true)   // as tall as the page; the strip shows its bottom
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(6)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}
