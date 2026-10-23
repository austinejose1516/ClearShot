import ClearShotCore
import SwiftUI

/// One screen's overlay: the area-drag, window-pick or whole-screen UI, depending on the shared pick mode,
/// and the capture bar at the bottom of the screen under the mouse.
struct CaptureOverlayView: View {
    let screenQuartzFrame: CGRect
    let state: OverlayState
    /// This screen had the mouse when the overlay opened: the bar goes here, and Full screen starts lit.
    let underMouse: Bool
    /// Room for the Dock, so the bar sits just above it like the other toolbars.
    let bottomInset: CGFloat
    let onSelectArea: (CGRect) -> Void
    let onPickWindow: (WindowInfo) -> Void
    let onPickFullScreen: () -> Void
    let onCancel: () -> Void

    var body: some View {
        picker
            .overlay(alignment: .bottom) {
                if state.showsBar, underMouse {
                    CaptureBarView(model: state.bar, onCancel: onCancel)
                        .padding(.bottom, bottomInset)
                }
            }
    }

    @ViewBuilder private var picker: some View {
        switch state.pickMode {
        case .area:
            SelectionOverlayView(onSelect: onSelectArea, onCancel: onCancel)
        case .window:
            WindowPickOverlayView(screenQuartzFrame: screenQuartzFrame, windows: state.windows, onPick: onPickWindow)
        case .fullScreen:
            FullScreenPickOverlayView(startsHovered: underMouse, onPick: onPickFullScreen)
        }
    }
}
