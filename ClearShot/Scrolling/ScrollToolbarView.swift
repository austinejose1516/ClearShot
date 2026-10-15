import ClearShotCore
import SwiftUI

/// The toolbar's one choice: who scrolls. It starts on By hand for every new scrolling capture.
@Observable
final class ScrollToolbarModel {
    var mode: ScrollCaptureState.Mode = .manual
}

/// Before the capture: who scrolls, Change Area and Start. The same look as the record toolbar.
struct ScrollToolbarView: View {
    let model: ScrollToolbarModel
    /// "Change Area", "Change Window", or nil for a full screen.
    let changeTitle: String?
    let onCancel: () -> Void
    let onChange: () -> Void
    let onStart: () -> Void
    let onPickAuto: () -> Void

    var body: some View {
        ToolbarCapsule {
            ToolbarCloseButton(help: "Cancel (Esc)", action: onCancel)
            ToolbarSeparator()
            HStack(spacing: 2) {
                OptionChip(title: "By hand", symbol: "hand.draw", isOn: model.mode == .manual,
                           help: "You scroll the page; ClearShot keeps adding to the picture") {
                    model.mode = .manual
                }
                OptionChip(title: "Auto", symbol: "arrow.down.to.line", isOn: model.mode == .automatic,
                           help: "ClearShot scrolls to the end of the page (needs the Accessibility permission)",
                           action: onPickAuto)
            }
            if let changeTitle {
                ToolbarSeparator()
                ToolbarChangeButton(title: changeTitle, action: onChange)
            }
            ToolbarActionButton(fill: AnyShapeStyle(.tint), help: "Start (Enter)", action: onStart) {
                Image(systemName: "play.fill").font(.system(size: 10, weight: .bold))
                Text("Start")
            }
        }
    }
}

/// During the capture, in the same spot: how tall the page is, Done and Cancel.
struct ScrollBarView: View {
    let state: ScrollCaptureState
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ToolbarCapsule {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tint)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 16)
                Text(status)
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(width: 230, alignment: .leading)   // a fixed width, so the bar never resizes
            .padding(.leading, 6)
            .animation(.snappy(duration: 0.2), value: state.pages)
            .animation(.snappy(duration: 0.2), value: state.reachedEnd)
            .animation(.snappy(duration: 0.2), value: state.lostTrack)
            ToolbarActionButton(fill: AnyShapeStyle(.tint), help: "Finish and save (Enter)", action: onDone) {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                Text("Done")
            }
            ToolbarSeparator()
            ToolbarCloseButton(help: "Cancel (Esc)", action: onCancel)
        }
    }

    private var symbol: String {
        if state.lostTrack { return "exclamationmark.triangle" }
        if state.reachedEnd { return "checkmark.circle" }
        return state.mode == .automatic ? "arrow.down" : "arrow.up.and.down"
    }

    private var status: String {
        let pages = "\(state.pages) \(state.pages == 1 ? "page" : "pages")"
        if state.lostTrack { return "Too fast · scroll back up a little" }
        if state.reachedEnd { return "End of page · \(pages)" }
        return state.mode == .automatic ? "Scrolling · \(pages)" : "\(pages) · scroll down"
    }
}
