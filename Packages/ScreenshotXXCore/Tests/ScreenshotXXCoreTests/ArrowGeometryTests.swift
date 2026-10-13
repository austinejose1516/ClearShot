import CoreGraphics
import Testing
@testable import ScreenshotXXCore

@Suite struct ArrowGeometryTests {
    @Test func headWingsSitBehindTheTipOnBothSides() {
        let head = ArrowGeometry.head(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0), length: 10, width: 8)
        #expect(abs(head.left.x - 90) < 0.001 && abs(head.left.y - 4) < 0.001)
        #expect(abs(head.right.x - 90) < 0.001 && abs(head.right.y + 4) < 0.001)
    }
}
