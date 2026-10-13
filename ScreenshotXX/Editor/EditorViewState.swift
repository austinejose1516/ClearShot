import Observation
import SwiftUI

/// View-only state of one editor window: zoom and the frame panel.
@Observable
final class EditorViewState {
    var zoom: CGFloat = 1
    var zoomIsFit = true
    var showsFramePanel = false
    /// A short help line shown over the canvas when a tool is picked.
    private(set) var tip: String?
    @ObservationIgnored private var tipTask: Task<Void, Never>?

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

    func fit(canvas: CGSize, in viewport: CGSize) {
        guard zoomIsFit, canvas.width > 0, canvas.height > 0 else { return }
        let margin: CGFloat = 48
        let fit = min((viewport.width - margin) / canvas.width, (viewport.height - margin) / canvas.height)
        zoom = max(0.05, min(1, fit))
    }

    func zoom(by factor: CGFloat) {
        zoomIsFit = false
        zoom = max(0.05, min(8, zoom * factor))
    }
}
