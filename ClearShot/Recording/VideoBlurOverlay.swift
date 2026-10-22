import AppKit
import ClearShotCore
import SwiftUI

/// The blur boxes drawn over the player, and the mouse while the Blur switch is on: drag on empty video draws
/// a new box, drag inside a box moves it, drag a corner dot resizes it, a click on empty video clears the
/// selection. With the switch off the boxes are only drawn and the mouse goes to the player.
struct VideoBlurOverlay: View {
    let state: VideoState
    let videoSize: CGSize
    /// After a box was added, moved, resized: the controller redraws the blurred frame.
    let onChanged: () -> Void

    @State private var drag: Drag?
    /// The box being drawn, in video pixels.
    @State private var pending: CGRect?

    private enum Drag {
        case draw(start: CGPoint)
        case move(id: VideoBlur.ID, from: CGRect)
        case resize(id: VideoBlur.ID, handle: HandleKind)
    }

    private static let dotSize: CGFloat = 10
    private static let grabTolerance: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let fitted = AspectFit.rect(for: videoSize, in: CGRect(origin: .zero, size: proxy.size))
            let scale = videoSize.width > 0 ? fitted.width / videoSize.width : 1
            ZStack(alignment: .topLeading) {
                Color.clear
                ForEach(state.blurs.regions) { region in
                    box(region.rect, on: fitted, scale: scale, selected: region.id == state.selectedBlur)
                }
                if let pending {
                    box(pending, on: fitted, scale: scale, selected: false).opacity(0.8)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(gesture(on: fitted, scale: scale))
            .onContinuousHover { phase in
                switch phase {
                case .active: NSCursor.crosshair.set()
                case .ended: NSCursor.arrow.set()
                }
            }
        }
        .allowsHitTesting(state.blurToolOn)
    }

    // MARK: - Drawing

    private func box(_ rect: CGRect, on fitted: CGRect, scale: CGFloat, selected: Bool) -> some View {
        let r = CGRect(x: fitted.minX + rect.minX * scale, y: fitted.minY + rect.minY * scale,
                       width: rect.width * scale, height: rect.height * scale)
        return ZStack {
            Rectangle().strokeBorder(.white.opacity(0.85), lineWidth: 3)
            Rectangle().strokeBorder(.tint, lineWidth: selected ? 2 : 1.5)
        }
        .frame(width: r.width, height: r.height)
        .overlay {
            if selected {
                ForEach(Array(corners(of: CGSize(width: r.width, height: r.height)).enumerated()), id: \.offset) { _, corner in
                    Circle()
                        .fill(.white)
                        .overlay(Circle().strokeBorder(.tint, lineWidth: 1.5))
                        .frame(width: Self.dotSize, height: Self.dotSize)
                        .position(corner)
                }
            }
        }
        .offset(x: r.minX, y: r.minY)
        .allowsHitTesting(false)
    }

    private func corners(of size: CGSize) -> [CGPoint] {
        [CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
    }

    // MARK: - The mouse

    private func gesture(on fitted: CGRect, scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let point = video(value.location, on: fitted, scale: scale)
                if drag == nil { drag = begin(at: video(value.startLocation, on: fitted, scale: scale), scale: scale) }
                switch drag {
                case .resize(let id, let handle)?:
                    state.blurs.resize(id, dragging: handle, to: point)
                case .move(let id, let from)?:
                    state.blurs.move(id, to: from.offsetBy(dx: value.translation.width / scale, dy: value.translation.height / scale))
                case .draw(let start)?:
                    pending = SelectionGeometry.normalizedRect(from: start, to: point)
                case nil:
                    break
                }
            }
            .onEnded { value in
                defer {
                    drag = nil
                    pending = nil
                }
                switch drag {
                case .draw(let start)?:
                    let rect = SelectionGeometry.normalizedRect(from: start, to: video(value.location, on: fitted, scale: scale))
                    guard let id = state.blurs.add(rect, mode: state.blurMode) else { return }   // a click: just deselected
                    state.selectedBlur = id
                    onChanged()
                case .move?, .resize?:
                    onChanged()
                case nil:
                    break
                }
            }
    }

    /// What the first point of a drag means: a corner of the selected box, a box, or empty video.
    private func begin(at start: CGPoint, scale: CGFloat) -> Drag {
        if let id = state.selectedBlur, let handle = state.blurs.handle(of: id, at: start, tolerance: Self.grabTolerance / scale) {
            return .resize(id: id, handle: handle)
        }
        if let id = state.blurs.region(at: start), let region = state.blurs[id] {
            state.selectedBlur = id
            return .move(id: id, from: region.rect)
        }
        state.selectedBlur = nil
        return .draw(start: start)
    }

    /// A point in the overlay, in video pixels.
    private func video(_ point: CGPoint, on fitted: CGRect, scale: CGFloat) -> CGPoint {
        CGPoint(x: (point.x - fitted.minX) / scale, y: (point.y - fitted.minY) / scale)
    }
}
