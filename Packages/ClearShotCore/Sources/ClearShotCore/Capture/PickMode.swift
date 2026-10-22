/// How the capture bar picks what to capture: drag an area, click a window, or click a whole screen.
public enum PickMode: String, CaseIterable, Sendable, Codable {
    case area, window, fullScreen

    public var title: String {
        switch self {
        case .area: "Area"
        case .window: "Window"
        case .fullScreen: "Full screen"
        }
    }

    /// SF Symbol name.
    public var symbol: String {
        switch self {
        case .area: "rectangle.dashed"
        case .window: "macwindow"
        case .fullScreen: "display"
        }
    }

    /// What to do now, shown on the bar.
    public var hint: String {
        switch self {
        case .area: "Drag an area"
        case .window: "Click a window"
        case .fullScreen: "Click a screen"
        }
    }

    /// What a finished capture is called (files, cards, logs).
    public var kind: CaptureKind {
        switch self {
        case .area: .area
        case .window: .window
        case .fullScreen: .fullScreen
        }
    }

    /// Space switches between Area and Window, as it always has; from Full screen it goes to Area.
    public var afterSpace: PickMode {
        switch self {
        case .area: .window
        case .window, .fullScreen: .area
        }
    }
}
