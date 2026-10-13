/// Light, dark, or follow the system.
public enum Appearance: String, CaseIterable, Sendable, Codable {
    case system, light, dark

    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// The app's accent colour: selected tool, selection dots, buttons, card highlights.
public enum AccentTheme: String, CaseIterable, Sendable, Codable {
    case ocean, violet, sunset, forest, graphite

    public var title: String {
        switch self {
        case .ocean: "Ocean"
        case .violet: "Violet"
        case .sunset: "Sunset"
        case .forest: "Forest"
        case .graphite: "Graphite"
        }
    }

    public var color: RGBAColor {
        switch self {
        case .ocean: RGBAColor(red: 0.098, green: 0.620, blue: 0.980)   // the blue of the app icon
        case .violet: RGBAColor(red: 0.545, green: 0.361, blue: 0.965)
        case .sunset: RGBAColor(red: 0.976, green: 0.451, blue: 0.086)
        case .forest: RGBAColor(red: 0.086, green: 0.639, blue: 0.290)
        case .graphite: RGBAColor(red: 0.420, green: 0.447, blue: 0.502)
        }
    }
}
