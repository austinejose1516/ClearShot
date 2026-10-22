import Observation

/// The capture bar's two choices: what to make and how to pick it. Both are remembered between uses; a menu
/// item sets what to make and keeps the remembered way of picking.
@Observable
public final class CaptureBarModel {
    public var action: CaptureAction
    public var pickMode: PickMode

    public init(action: CaptureAction, pickMode: PickMode) {
        self.action = action
        self.pickMode = pickMode
    }

    /// What to do now, shown on the bar.
    public var hint: String { pickMode.hint }

    /// The remembered choices, with `action` on top when a menu item chose it.
    public static func remembered(from settings: AppSettings, action: CaptureAction?) -> CaptureBarModel {
        CaptureBarModel(action: action ?? settings.lastCaptureAction, pickMode: settings.lastPickMode)
    }

    public func remember(in settings: AppSettings) {
        settings.lastCaptureAction = action
        settings.lastPickMode = pickMode
    }
}
