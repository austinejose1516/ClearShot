import Observation
import ClearShotCore

/// Shared by every screen's overlay so Space switches all of them together.
@Observable
final class OverlayState {
    var mode: OverlayCaptureSession.Mode
    var windows: [WindowInfo] = []

    init(mode: OverlayCaptureSession.Mode) {
        self.mode = mode
    }
}
