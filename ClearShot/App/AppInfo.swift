import AppKit
import SwiftUI

/// Name, version, links and the brand header, in one place.
enum AppInfo {
    static let name = "ClearShot"
    static let tagline = "Free and open-source screenshots for your Mac"
    static let repository = URL(string: "https://github.com/austinejose1516/ClearShot")!
    static let issues = URL(string: "https://github.com/austinejose1516/ClearShot/issues")!
    static let releases = URL(string: "https://github.com/austinejose1516/ClearShot/releases/latest")!
    static let latestReleaseAPI = URL(string: "https://api.github.com/repos/austinejose1516/ClearShot/releases/latest")!
    static let upgradeCommand = "brew upgrade --cask clearshot"

    /// "0.2.0"
    static var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    /// The standard About window, with an open-source note and the GitHub link.
    static func showAboutPanel() {
        let credits = NSMutableAttributedString(
            string: "Free and open source (MIT licence).\n",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
        credits.append(NSAttributedString(
            string: "github.com/austinejose1516/ClearShot",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .link: repository]))
        WindowPresenter.becomeRegularApp()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}

/// App icon, name and a short line, used at the top of Settings and the welcome window.
struct BrandHeader: View {
    var iconSize: CGFloat = 56
    var subtitle: String = AppInfo.tagline

    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: iconSize, height: iconSize)
            VStack(alignment: .leading, spacing: 3) {
                Text(AppInfo.name).font(.title2.bold())
                Text(subtitle).foregroundStyle(.secondary)
            }
        }
    }
}

/// A small rounded label, e.g. "Free" or "Open source".
struct Badge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(.tint.opacity(0.15), in: Capsule())
            .foregroundStyle(.tint)
    }
}
