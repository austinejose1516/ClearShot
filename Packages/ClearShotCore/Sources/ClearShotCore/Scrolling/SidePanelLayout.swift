import CoreGraphics

/// Where the scrolling capture's live preview goes: beside the area, as tall as it, on the visible screen.
/// Any coordinates work as long as the area and the screen use the same ones.
public enum SidePanelLayout {
    public static let gap: CGFloat = 12
    public static let minimumHeight: CGFloat = 160

    /// Right of the area when it fits, else left of it, else just inside the screen's right edge (a full
    /// screen area). Vertically centred on the area and kept on the screen.
    public static func frame(width: CGFloat, beside area: CGRect, in visible: CGRect) -> CGRect {
        let height = min(max(area.height, minimumHeight), visible.height - 2 * gap)
        let y = min(max(area.midY - height / 2, visible.minY), visible.maxY - height)
        let x: CGFloat
        if area.maxX + gap + width <= visible.maxX {
            x = area.maxX + gap
        } else if area.minX - gap - width >= visible.minX {
            x = area.minX - gap - width
        } else {
            x = visible.maxX - gap - width
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
