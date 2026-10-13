import CoreGraphics

/// Where the Quick Access cards sit: a row along the bottom-left of a screen's visible area, newest on the left.
public enum QuickAccessLayout {
    public static let cardSize = CGSize(width: 232, height: 212)
    public static let margin: CGFloat = 16
    public static let gap: CGFloat = 8

    public static func maxVisible(in visibleFrame: CGRect) -> Int {
        max(0, Int((visibleFrame.width - margin + gap) / (cardSize.width + gap)))
    }

    /// AppKit coordinates (origin bottom-left). Index 0 is the newest card.
    public static func frames(count: Int, in visibleFrame: CGRect) -> [CGRect] {
        (0..<min(count, maxVisible(in: visibleFrame))).map { index in
            CGRect(x: visibleFrame.minX + margin + CGFloat(index) * (cardSize.width + gap),
                   y: visibleFrame.minY + margin,
                   width: cardSize.width, height: cardSize.height)
        }
    }
}
