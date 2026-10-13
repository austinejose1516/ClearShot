import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct QuickAccessLayoutTests {
    @Test func cardsLineUpFromTheBottomLeftNewestFirst() {
        let frames = QuickAccessLayout.frames(count: 3, in: CGRect(x: 0, y: 0, width: 1800, height: 1100))
        #expect(frames.map(\.minX) == [16, 256, 496])
        #expect(frames.allSatisfy { $0.minY == 16 && $0.size == QuickAccessLayout.cardSize })
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
}
