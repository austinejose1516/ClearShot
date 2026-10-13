import ClearShotCore
import SwiftUI

/// One screen's overlay. Shows the area-drag UI or the window-pick UI depending on the shared mode.
struct CaptureOverlayView: View {
    let frozen: CGImage
    let screenQuartzFrame: CGRect
    let state: OverlayState
    let onSelectArea: (CGRect) -> Void
    let onPickWindow: (WindowInfo) -> Void
    let onCancel: () -> Void

    var body: some View {
        switch state.mode {
        case .area:
            SelectionOverlayView(frozen: frozen, onSelect: onSelectArea, onCancel: onCancel)
        case .window:
            WindowPickOverlayView(frozen: frozen, screenQuartzFrame: screenQuartzFrame,
                                  windows: state.windows, onPick: onPickWindow)
        }
    }
}
