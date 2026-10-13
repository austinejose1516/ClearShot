/// A colour the editor can store and export. SwiftUI's Color is not Codable, so annotations use this.
public struct RGBAColor: Equatable, Hashable, Sendable, Codable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    // A softer palette than pure primaries (close to Tailwind's 500 shades).
    public static let red = RGBAColor(red: 0.937, green: 0.267, blue: 0.267)
    public static let orange = RGBAColor(red: 0.976, green: 0.451, blue: 0.086)
    public static let yellow = RGBAColor(red: 0.980, green: 0.800, blue: 0.082)
    public static let green = RGBAColor(red: 0.133, green: 0.773, blue: 0.369)
    public static let blue = RGBAColor(red: 0.231, green: 0.510, blue: 0.965)
    public static let purple = RGBAColor(red: 0.545, green: 0.361, blue: 0.965)
    public static let pink = RGBAColor(red: 0.925, green: 0.282, blue: 0.600)
    public static let black = RGBAColor(red: 0.067, green: 0.094, blue: 0.153)
    public static let white = RGBAColor(red: 1, green: 1, blue: 1)

    public static let presets: [RGBAColor] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .black, .white]

    public func withAlpha(_ alpha: Double) -> RGBAColor {
        RGBAColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Same hue, ignoring alpha.
    public func sameColor(as other: RGBAColor) -> Bool {
        red == other.red && green == other.green && blue == other.blue
    }
}
