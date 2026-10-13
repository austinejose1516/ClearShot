import ScreenshotXXCore
import SwiftUI

extension Color {
    init(_ rgba: RGBAColor) {
        self.init(red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}
