import Observation
import ClearShotCore

/// Shared by every screen's overlay so Space switches all of them together.
@Observable
final class OverlayState {
    /// What to make and how to pick it. Shown and changeable on the bar when `showsBar`; otherwise only the
    /// way of picking matters, and Space still switches it.
    let bar: CaptureBarModel
    let showsBar: Bool
    var windows: [WindowInfo] = []

    init(bar: CaptureBarModel, showsBar: Bool) {
        self.bar = bar
        self.showsBar = showsBar
    }

    var pickMode: PickMode {
        get { bar.pickMode }
        set { bar.pickMode = newValue }
    }
}
