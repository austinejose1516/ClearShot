import AppKit
import ClearShotCore
import SwiftUI

extension Color {
    init(_ rgba: RGBAColor) {
        self.init(red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}

extension RGBAColor {
    /// From a colour picked in the system colour panel (converted to sRGB).
    init(_ color: Color) {
        let srgb = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(red: Double(srgb.redComponent), green: Double(srgb.greenComponent),
                  blue: Double(srgb.blueComponent), alpha: Double(srgb.alphaComponent))
    }
}
