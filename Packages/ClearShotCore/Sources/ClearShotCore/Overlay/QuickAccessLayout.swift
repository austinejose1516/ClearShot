import CoreGraphics

/// Where the Quick Access cards sit: a row along the bottom-left of a screen's visible area, newest on the left,
/// except the cards the user moved somewhere else.
public enum QuickAccessLayout {
    public static let cardSize = CGSize(width: 232, height: 168)
    public static let margin: CGFloat = 16
    public static let gap: CGFloat = 8
    /// Transparent room around the card inside its panel, so entrance and hover animations are not clipped.
    public static let panelMargin: CGFloat = 24
    /// The picture's inset inside the card.
    public static let thumbnailPadding: CGFloat = 10

    /// Where a card shows its picture: fitted inside the padding, centred.
    public static func thumbnailRect(imageSize: CGSize, inCard card: CGRect) -> CGRect {
        AspectFit.rect(for: imageSize, in: card.insetBy(dx: thumbnailPadding, dy: thumbnailPadding))
    }

    public static func maxVisible(in visibleFrame: CGRect) -> Int {
        max(0, Int((visibleFrame.width - margin + gap) / (cardSize.width + gap)))
    }

    /// Where a card the user moved ends up: fully inside the screen it mostly covers. A card on no screen (its
    /// screen was unplugged) goes to the first one, the main screen. `screens` are visible frames.
    public static func keptOnScreen(_ card: CGRect, screens: [CGRect]) -> CGRect {
        func coveredArea(_ screen: CGRect) -> CGFloat {
            let overlap = screen.intersection(card)
            return overlap.isNull ? 0 : overlap.width * overlap.height
        }
        let best = screens.max { coveredArea($0) < coveredArea($1) }
        guard let screen = (best.map(coveredArea) ?? 0) > 0 ? best : screens.first else { return card }
        // max before min: a card bigger than the screen keeps its left and bottom edges on it.
        let x = max(screen.minX, min(card.minX, screen.maxX - card.width))
        let y = max(screen.minY, min(card.minY, screen.maxY - card.height))
        return CGRect(origin: CGPoint(x: x, y: y), size: card.size)
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
