import Observation
import ClearShotCore
import SwiftUI

/// View-only state of one editor window: zoom and the frame panel.
@Observable
final class EditorViewState {
    var canvasZoom = CanvasZoom()
    var showsFramePanel = false
    /// 0…1 while an upload runs (the Upload button shows a bar and ignores clicks); nil otherwise.
    var uploadProgress: Double?
    /// A short help line shown over the canvas when a tool is picked.
    private(set) var tip: String?
    @ObservationIgnored private var tipTask: Task<Void, Never>?

    var zoom: CGFloat { canvasZoom.scale }

    func showTip(_ text: String) {
        tipTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { tip = text }
        tipTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            dismissTip()
        }
    }

    func dismissTip() {
        tipTask?.cancel()
        guard tip != nil else { return }
        withAnimation(.easeIn(duration: 0.2)) { tip = nil }
    }

    /// The canvas view reports both sizes, so "Fit" always has something current to fit into.
    func layoutChanged(canvas: CGSize, viewport: CGSize) {
        canvasZoom.canvasSize = canvas
        canvasZoom.viewportSize = viewport
    }

    /// ⌘+ / ⌘−: a short ease, so the canvas glides rather than jumps. (A pinch sets the zoom directly.)
    func zoom(by factor: CGFloat) {
        withAnimation(.easeOut(duration: 0.2)) { canvasZoom.zoom(by: factor) }
    }

    /// The zoom menu: Fit, 50 %, 100 %, 200 %.
    func setZoomMode(_ mode: CanvasZoom.Mode) {
        withAnimation(.easeOut(duration: 0.2)) { canvasZoom.mode = mode }
    }
}
