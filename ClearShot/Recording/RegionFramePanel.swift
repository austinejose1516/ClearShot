import AppKit
import ClearShotCore
import SwiftUI

/// A thin red border around the area being recorded (or scrolled). Clicks go straight through it.
final class RegionFramePanel: NSPanel {
    private static let inset: CGFloat = 3

    init(region: ScreenRegion) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let quartz = region.quartzRect
        // Quartz (top-left origin) back to AppKit (bottom-left origin) for the window frame.
        let appKit = CGRect(x: quartz.minX, y: primaryHeight - quartz.maxY, width: quartz.width, height: quartz.height)
        super.init(contentRect: appKit.insetBy(dx: -Self.inset, dy: -Self.inset),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = NSHostingView(rootView: Rectangle()
            .strokeBorder(.red.opacity(0.85), lineWidth: 2)
            .padding(Self.inset - 2))
    }
}
