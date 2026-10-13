import CoreGraphics
import Foundation

public struct GradientPreset: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let name: String
    public let start: RGBAColor
    public let end: RGBAColor

    public static let all: [GradientPreset] = [
        GradientPreset(id: "sunset", name: "Sunset", start: RGBAColor(red: 1, green: 0.42, blue: 0.42), end: RGBAColor(red: 1, green: 0.75, blue: 0.3)),
        GradientPreset(id: "ocean", name: "Ocean", start: RGBAColor(red: 0.13, green: 0.55, blue: 0.95), end: RGBAColor(red: 0, green: 0.85, blue: 0.8)),
        GradientPreset(id: "mint", name: "Mint", start: RGBAColor(red: 0.2, green: 0.8, blue: 0.6), end: RGBAColor(red: 0.6, green: 0.95, blue: 0.7)),
        GradientPreset(id: "lavender", name: "Lavender", start: RGBAColor(red: 0.55, green: 0.45, blue: 0.95), end: RGBAColor(red: 0.9, green: 0.6, blue: 0.95)),
        GradientPreset(id: "peach", name: "Peach", start: RGBAColor(red: 1, green: 0.6, blue: 0.5), end: RGBAColor(red: 1, green: 0.85, blue: 0.7)),
        GradientPreset(id: "midnight", name: "Midnight", start: RGBAColor(red: 0.1, green: 0.12, blue: 0.25), end: RGBAColor(red: 0.25, green: 0.2, blue: 0.45)),
        GradientPreset(id: "slate", name: "Slate", start: RGBAColor(red: 0.3, green: 0.33, blue: 0.38), end: RGBAColor(red: 0.55, green: 0.58, blue: 0.63)),
        GradientPreset(id: "candy", name: "Candy", start: RGBAColor(red: 0.95, green: 0.35, blue: 0.65), end: RGBAColor(red: 0.45, green: 0.55, blue: 1)),
    ]
}

public enum Background: Equatable, Sendable, Codable {
    case none
    case solid(RGBAColor)
    case gradient(GradientPreset)
    case image(URL)
}

/// Everything around the image: background, padding, rounded corners, shadow.
public struct FrameStyle: Equatable, Sendable, Codable {
    public var padding: CGFloat = 0
    public var cornerRadius: CGFloat = 0
    /// 0 = no shadow; up to 100 = big soft shadow.
    public var shadow: CGFloat = 0
    public var background: Background = .none

    public init() {}

    /// What the Frame panel applies when it is opened on an untouched frame, so every control shows an effect.
    public static var starter: FrameStyle {
        var frame = FrameStyle()
        frame.padding = 64
        frame.cornerRadius = 16
        frame.shadow = 40
        frame.background = .gradient(GradientPreset.all[1])
        return frame
    }
}
