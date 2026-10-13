import ClearShotCore
import SwiftUI

/// Hover highlights the front-most window under the mouse; click picks it.
struct WindowPickOverlayView: View {
    let frozen: CGImage
    let screenQuartzFrame: CGRect
    let windows: [WindowInfo]
    let onPick: (WindowInfo) -> Void

    @State private var hovered: WindowInfo?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let highlight = hovered.map(localRect)
            ZStack(alignment: .topLeading) {
                Image(decorative: frozen, scale: 1)
                    .resizable()
                    .frame(width: size.width, height: size.height)
                DimLayer(size: size, hole: highlight)
                if let hovered, let highlight {
                    WindowHighlight(rect: highlight, title: hovered.title ?? "")
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let point): hovered = WindowPicker.window(at: quartzPoint(point), in: windows)
                case .ended: hovered = nil
                }
            }
            .onTapGesture {
                if let hovered { onPick(hovered) }
            }
        }
        .ignoresSafeArea()
    }

    private func localRect(_ window: WindowInfo) -> CGRect {
        ScreenCoordinates.viewRect(fromQuartz: window.frame, screenQuartzFrame: screenQuartzFrame)
    }

    private func quartzPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: screenQuartzFrame.minX + point.x, y: screenQuartzFrame.minY + point.y)
    }
}

private struct WindowHighlight: View {
    let rect: CGRect
    let title: String

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.white.opacity(0.12))
            .stroke(.tint, lineWidth: 2)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .allowsHitTesting(false)
        if !title.isEmpty {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 6))
                .fixedSize()
                .frame(maxWidth: max(40, rect.width - 16), alignment: .leading)
                .offset(x: rect.minX + 8, y: rect.minY + 8)
                .allowsHitTesting(false)
        }
    }
}
