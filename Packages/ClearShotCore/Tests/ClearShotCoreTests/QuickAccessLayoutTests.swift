import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct QuickAccessLayoutTests {
    @Test func cardsLineUpFromTheBottomLeftNewestFirst() {
        let frames = QuickAccessLayout.frames(count: 3, in: CGRect(x: 0, y: 0, width: 1800, height: 1100))
        #expect(frames.map(\.minX) == [16, 256, 496])
        #expect(frames.allSatisfy { $0.minY == 16 && $0.size == QuickAccessLayout.cardSize })
    }

    @Test func theThumbnailFitsInsideTheCardWithItsPadding() {
        let card = CGRect(x: 16, y: 16, width: 232, height: 168)
        // A wide picture: full width inside the padding, centred up and down.
        let wide = QuickAccessLayout.thumbnailRect(imageSize: CGSize(width: 2120, height: 740), inCard: card)
        #expect(wide.width == 212)
        #expect(abs(wide.height - 74) < 0.001)
        #expect(wide.midX == card.midX && wide.midY == card.midY)
        // A tall one: full height inside the padding.
        let tall = QuickAccessLayout.thumbnailRect(imageSize: CGSize(width: 100, height: 1480), inCard: card)
        #expect(tall.height == 148)
    }

    @Test func cardsThatDoNotFitAreDropped() {
        let narrow = CGRect(x: 0, y: 0, width: 500, height: 800)
        #expect(QuickAccessLayout.maxVisible(in: narrow) == 2)
        #expect(QuickAccessLayout.frames(count: 5, in: narrow).count == 2)
    }

    @Test func dockOffsetComesFromTheVisibleFrameOrigin() {
        let frames = QuickAccessLayout.frames(count: 1, in: CGRect(x: 100, y: 70, width: 1800, height: 1000))
        #expect(frames[0].origin == CGPoint(x: 116, y: 86))
    }

    // MARK: - A card the user moved stays on a screen

    private let laptop = CGRect(x: 0, y: 0, width: 1800, height: 1100)
    /// A second screen to the right of the laptop.
    private let monitor = CGRect(x: 1800, y: 0, width: 2560, height: 1400)

    private func card(x: CGFloat, y: CGFloat) -> CGRect {
        CGRect(origin: CGPoint(x: x, y: y), size: QuickAccessLayout.cardSize)
    }

    @Test func aMovedCardInsideTheScreenStaysWhereItWasDropped() {
        let dropped = card(x: 600, y: 400)
        #expect(QuickAccessLayout.keptOnScreen(dropped, screens: [laptop]) == dropped)
    }

    @Test func aMovedCardPastAnEdgeIsPulledBackInside() {
        // Past the top-right corner of the only screen.
        let kept = QuickAccessLayout.keptOnScreen(card(x: 1700, y: 1050), screens: [laptop])
        #expect(kept == card(x: 1800 - 232, y: 1100 - 168))
        // Past the bottom-left corner.
        #expect(QuickAccessLayout.keptOnScreen(card(x: -50, y: -20), screens: [laptop]) == card(x: 0, y: 0))
    }

    @Test func aCardAcrossTwoScreensGoesOntoTheOneItMostlyCovers() {
        // 200 of its 232 points are on the monitor.
        let kept = QuickAccessLayout.keptOnScreen(card(x: 1768, y: 300), screens: [laptop, monitor])
        #expect(kept == card(x: 1800, y: 300))
    }

    @Test func aCardOnAScreenThatWasUnpluggedGoesToTheMainScreen() {
        // It sat on the monitor; only the laptop (the main screen, listed first) is left.
        let kept = QuickAccessLayout.keptOnScreen(card(x: 3000, y: 500), screens: [laptop])
        #expect(kept == card(x: 1800 - 232, y: 500))
    }
}
