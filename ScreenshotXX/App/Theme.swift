import AppKit
import ScreenshotXXCore
import SwiftUI

enum Theme {
    /// Light, Dark or System for every window, cards and capture overlays included.
    static func apply(_ appearance: Appearance) {
        NSApp.appearance = switch appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// Sets the accent colour as the tint, so controls and custom drawing (`.tint` shape style) follow the theme.
private struct AccentTint: ViewModifier {
    @Environment(AppSettings.self) private var settings

    func body(content: Content) -> some View {
        content.tint(Color(settings.accent.color))
    }
}

extension View {
    /// The root modifier for every window and panel: settings in the environment, accent colour as the tint.
    func themed(_ settings: AppSettings) -> some View {
        modifier(AccentTint()).environment(settings)
    }
}

/// Soft dots behind the editor canvas.
struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 18
            var dots = Path()
            for x in stride(from: spacing / 2, to: size.width, by: spacing) {
                for y in stride(from: spacing / 2, to: size.height, by: spacing) {
                    dots.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
                }
            }
            context.fill(dots, with: .color(.primary.opacity(0.13)))
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}
