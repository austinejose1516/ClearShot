import ClearShotCore
import SwiftUI

/// Dims the screen, which goes on moving underneath, and lets the user drag a rectangle that shows it undimmed.
/// A crosshair with the pointer's place leads up to the drag; the box gets corner brackets, a thirds grid and
/// its size. Reports the rect in view points.
struct SelectionOverlayView: View {
    /// Tracked by the panel, which sees the mouse first.
    let drag: AreaDrag

    @State private var hover: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                DimLayer(size: size, hole: drag.rect)
                if let selection = drag.rect {
                    SelectionFrame(rect: selection, canvas: size)
                } else if let hover {
                    Crosshair(point: hover, size: size)
                }
                if let point = drag.current ?? hover {
                    PointerTag(point: point, canvas: size)
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
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

/// The box being dragged: an accent-coloured edge with brackets on the corners, a thirds grid when there is
/// room, and the size just below (above, near the bottom of the screen).
private struct SelectionFrame: View {
    let rect: CGRect
    let canvas: CGSize

    private var labelBelow: Bool { rect.maxY + 34 < canvas.height }

    var body: some View {
        if SelectionGeometry.showsGrid(for: rect) {
            ThirdsGrid(box: rect)
                .stroke(.white.opacity(0.25), lineWidth: 1)
                .allowsHitTesting(false)
        }
        Rectangle()
            .stroke(.tint, lineWidth: 1.5)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .allowsHitTesting(false)
        CornerBrackets(box: rect)
            .stroke(.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .square))
            .allowsHitTesting(false)
        GlassTag(text: "\(Int(rect.width.rounded())) × \(Int(rect.height.rounded()))")
            .offset(x: rect.minX, y: labelBelow ? rect.maxY + 8 : max(0, rect.minY - 32))
    }
}

/// Two lines each way, a third of the box apart.
private struct ThirdsGrid: Shape {
    let box: CGRect

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        for fraction in [1.0 / 3.0, 2.0 / 3.0] {
            let x = box.minX + box.width * fraction
            path.move(to: CGPoint(x: x, y: box.minY))
            path.addLine(to: CGPoint(x: x, y: box.maxY))
            let y = box.minY + box.height * fraction
            path.move(to: CGPoint(x: box.minX, y: y))
            path.addLine(to: CGPoint(x: box.maxX, y: y))
        }
        return path
    }
}

/// An L on each corner of the box, just outside its edge; the arms shrink to fit a small box.
private struct CornerBrackets: Shape {
    let box: CGRect

    nonisolated func path(in rect: CGRect) -> Path {
        let b = box.insetBy(dx: -2, dy: -2)
        let arm = min(12, b.width / 2, b.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: b.minX, y: b.minY + arm))
        path.addLine(to: CGPoint(x: b.minX, y: b.minY))
        path.addLine(to: CGPoint(x: b.minX + arm, y: b.minY))
        path.move(to: CGPoint(x: b.maxX - arm, y: b.minY))
        path.addLine(to: CGPoint(x: b.maxX, y: b.minY))
        path.addLine(to: CGPoint(x: b.maxX, y: b.minY + arm))
        path.move(to: CGPoint(x: b.maxX, y: b.maxY - arm))
        path.addLine(to: CGPoint(x: b.maxX, y: b.maxY))
        path.addLine(to: CGPoint(x: b.maxX - arm, y: b.maxY))
        path.move(to: CGPoint(x: b.minX + arm, y: b.maxY))
        path.addLine(to: CGPoint(x: b.minX, y: b.maxY))
        path.addLine(to: CGPoint(x: b.minX, y: b.maxY - arm))
        return path
    }
}

/// A white hairline each way through the pointer, with a faint dark edge so it shows on light content too.
private struct Crosshair: View {
    let point: CGPoint
    let size: CGSize

    var body: some View {
        line(width: 1, height: size.height).offset(x: point.x)
        line(width: size.width, height: 1).offset(y: point.y)
    }

    private func line(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(.white.opacity(0.75))
            .frame(width: width, height: height)
            .background {
                Rectangle()
                    .fill(.black.opacity(0.25))
                    .frame(width: width == 1 ? 3 : width, height: height == 1 ? 3 : height)
            }
            .allowsHitTesting(false)
    }
}

/// The pointer's place on this screen, in points from the top-left, beside the pointer.
private struct PointerTag: View {
    let point: CGPoint
    let canvas: CGSize

    var body: some View {
        let origin = SelectionGeometry.tagOrigin(near: point, size: GlassTag.roughSize, in: canvas, gap: 14)
        GlassTag(text: "\(Int(point.x.rounded())), \(Int(point.y.rounded()))")
            .offset(x: origin.x, y: origin.y)
    }
}
