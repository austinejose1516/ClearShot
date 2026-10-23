import ClearShotCore
import SwiftUI

/// One screen's overlay: the area-drag, window-pick or whole-screen UI, depending on the shared pick mode,
/// and the capture bar at the bottom of the screen under the mouse.
struct CaptureOverlayView: View {
    let screenQuartzFrame: CGRect
    /// This screen's drag, tracked by its panel.
    let drag: AreaDrag
    let state: OverlayState
    /// This screen had the mouse when the overlay opened: the bar goes here, and Full screen starts lit.
    let underMouse: Bool
    /// Room for the Dock, so the bar sits just above it like the other toolbars.
    let bottomInset: CGFloat
    /// Room for the menu bar, so the hint sits just under it.
    let topInset: CGFloat
    /// Where the bar is, so the panel knows a click there is not a drag.
    let onBarFrame: (CGRect) -> Void
    let onPickWindow: (WindowInfo) -> Void
    let onPickFullScreen: () -> Void
    let onCancel: () -> Void

    var body: some View {
        picker
            .overlay(alignment: .bottom) {
                if state.showsBar, underMouse {
                    CaptureBarView(model: state.bar, onCancel: onCancel)
                        .padding(.bottom, bottomInset)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onBarFrame($0) }
                }
            }
            .overlay(alignment: .top) {
                // The shortcuts open the picker without the bar, so the keys are told here instead.
                if !state.showsBar, underMouse {
                    GlassTag(text: "\(state.pickMode.hint) · Space: \(state.pickMode.afterSpace.title.lowercased()) · Esc: cancel")
                        .padding(.top, topInset + 12)
                        .animation(.snappy(duration: 0.2), value: state.pickMode)
                }
            }
    }

    @ViewBuilder private var picker: some View {
        switch state.pickMode {
        case .area:
            SelectionOverlayView(drag: drag)
        case .window:
            WindowPickOverlayView(screenQuartzFrame: screenQuartzFrame, windows: state.windows, onPick: onPickWindow)
        case .fullScreen:
            FullScreenPickOverlayView(startsHovered: underMouse, onPick: onPickFullScreen)
        }
    }
}
