import ClearShotCore
import SwiftUI

/// The bar at the bottom of the dimmed screen, like the Mac's own ⇧⌘5 bar: what to make, how to pick it,
/// and what to do now.
struct CaptureBarView: View {
    let model: CaptureBarModel
    let onCancel: () -> Void

    var body: some View {
        ToolbarCapsule {
            ToolbarCloseButton(help: "Cancel (Esc)", action: onCancel)
            ToolbarSeparator()
            ForEach(CaptureAction.allCases, id: \.self) { action in
                OptionChip(title: action.title, symbol: action.symbol, isOn: model.action == action, help: Self.help(for: action)) {
                    model.action = action
                }
            }
            ToolbarSeparator()
            ForEach(PickMode.allCases, id: \.self) { mode in
                OptionChip(title: mode.title, symbol: mode.symbol, isOn: model.pickMode == mode, help: mode.hint) {
                    model.pickMode = mode
                }
            }
            ToolbarSeparator()
            Text(model.hint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .frame(minWidth: 104, alignment: .leading)
        }
        .animation(.snappy(duration: 0.2), value: model.pickMode)
        .animation(.snappy(duration: 0.2), value: model.action)
    }

    private static func help(for action: CaptureAction) -> String {
        switch action {
        case .screenshot: "Take a screenshot"
        case .scrolling: "One tall picture of a long page"
        case .recording: "Record the screen"
        }
    }
}
