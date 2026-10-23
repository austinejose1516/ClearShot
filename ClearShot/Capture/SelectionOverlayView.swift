import ClearShotCore
import SwiftUI

/// Dims the screen, which goes on moving underneath, and lets the user drag a rectangle that shows it undimmed.
/// Reports the rect in view points.
struct SelectionOverlayView: View {
    let onSelect: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var hover: CGPoint?

    private var selection: CGRect? {
        guard let dragStart, let dragCurrent else { return nil }
        return SelectionGeometry.normalizedRect(from: dragStart, to: dragCurrent)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                DimLayer(size: size, hole: selection)
                if let selection {
                    SelectionFrame(rect: selection, canvas: size)
                } else if let hover {
                    Crosshair(point: hover, size: size)
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if dragStart == nil { dragStart = value.startLocation }
                        dragCurrent = value.location
                    }
                    .onEnded { value in
                        let rect = SelectionGeometry.normalizedRect(from: value.startLocation, to: value.location)
                        dragStart = nil
                        dragCurrent = nil
                        if SelectionGeometry.isUsable(rect) { onSelect(rect) } else { onCancel() }
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let point): hover = point
                case .ended: hover = nil
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct SelectionFrame: View {
    let rect: CGRect
    let canvas: CGSize

    private var labelBelow: Bool { rect.maxY + 34 < canvas.height }

    var body: some View {
        Rectangle()
            .stroke(.white, lineWidth: 1)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .allowsHitTesting(false)
        Text("\(Int(rect.width.rounded())) × \(Int(rect.height.rounded()))")
            .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 6))
            .fixedSize()
            .offset(x: rect.minX, y: labelBelow ? rect.maxY + 6 : max(0, rect.minY - 28))
            .allowsHitTesting(false)
    }
}

private struct Crosshair: View {
    let point: CGPoint
    let size: CGSize

    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.6))
            .frame(width: 1, height: size.height)
            .offset(x: point.x)
            .allowsHitTesting(false)
        Rectangle()
            .fill(.white.opacity(0.6))
            .frame(width: size.width, height: 1)
            .offset(y: point.y)
            .allowsHitTesting(false)
    }
}
