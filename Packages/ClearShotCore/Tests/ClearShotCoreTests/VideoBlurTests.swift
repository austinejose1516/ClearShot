import Foundation
import Testing
@testable import ClearShotCore

@Suite struct VideoBlurTests {
    private let frame = CGSize(width: 1000, height: 600)

    @Test func addingClampsToTheFrameAndRefusesTinyBoxes() {
        var blurs = VideoBlurs(frame: frame)
        let id = blurs.add(CGRect(x: -20, y: 550, width: 100, height: 100), mode: .blur)
        #expect(id != nil && blurs.regions.count == 1)
        #expect(blurs.regions[0].rect == CGRect(x: 0, y: 550, width: 80, height: 50))
        #expect(blurs.add(CGRect(x: 10, y: 10, width: 7, height: 50), mode: .blur) == nil)
        #expect(blurs.add(CGRect(x: 10, y: 10, width: 50, height: 7), mode: .blur) == nil)
        #expect(blurs.regions.count == 1 && !blurs.isEmpty)
    }

    @Test func aBoxDrawnBackwardsIsStandardized() {
        var blurs = VideoBlurs(frame: frame)
        let id = blurs.add(CGRect(x: 300, y: 200, width: -100, height: -50), mode: .blur)!
        #expect(blurs[id]?.rect == CGRect(x: 200, y: 150, width: 100, height: 50))
    }

    @Test func theNewestBoxIsHitFirst() {
        var blurs = VideoBlurs(frame: frame)
        let a = blurs.add(CGRect(x: 0, y: 0, width: 200, height: 200), mode: .blur)!
        let b = blurs.add(CGRect(x: 100, y: 100, width: 200, height: 200), mode: .pixelate)!
        #expect(blurs.region(at: CGPoint(x: 150, y: 150)) == b)
        #expect(blurs.region(at: CGPoint(x: 50, y: 50)) == a)
        #expect(blurs.region(at: CGPoint(x: 500, y: 500)) == nil)
    }

    @Test func cornerHandlesAreFoundWithinTolerance() {
        var blurs = VideoBlurs(frame: frame)
        let id = blurs.add(CGRect(x: 100, y: 100, width: 200, height: 100), mode: .blur)!
        #expect(blurs.handle(of: id, at: CGPoint(x: 104, y: 97), tolerance: 8) == .topLeft)
        #expect(blurs.handle(of: id, at: CGPoint(x: 300, y: 200), tolerance: 8) == .bottomRight)
        #expect(blurs.handle(of: id, at: CGPoint(x: 298, y: 103), tolerance: 8) == .topRight)
        #expect(blurs.handle(of: id, at: CGPoint(x: 102, y: 198), tolerance: 8) == .bottomLeft)
        #expect(blurs.handle(of: id, at: CGPoint(x: 200, y: 150), tolerance: 8) == nil)
        #expect(blurs.handle(of: UUID(), at: CGPoint(x: 100, y: 100), tolerance: 8) == nil)
    }

    @Test func movingKeepsTheBoxInsideTheFrame() {
        var blurs = VideoBlurs(frame: frame)
        let id = blurs.add(CGRect(x: 100, y: 100, width: 200, height: 100), mode: .blur)!
        blurs.move(id, to: CGRect(x: 900, y: -50, width: 200, height: 100))
        #expect(blurs[id]?.rect == CGRect(x: 800, y: 0, width: 200, height: 100))
        blurs.move(id, to: CGRect(x: 10, y: 20, width: 200, height: 100))
        #expect(blurs[id]?.rect == CGRect(x: 10, y: 20, width: 200, height: 100))
    }

    @Test func resizingNeverGoesBelowTheSmallestSide() {
        var blurs = VideoBlurs(frame: frame)
        let id = blurs.add(CGRect(x: 100, y: 100, width: 200, height: 100), mode: .blur)!
        blurs.resize(id, dragging: .bottomRight, to: CGPoint(x: 102, y: 103))
        #expect(blurs[id]?.rect == CGRect(x: 100, y: 100, width: 8, height: 8))
        blurs.resize(id, dragging: .topLeft, to: CGPoint(x: -30, y: -30))
        #expect(blurs[id]?.rect == CGRect(x: 0, y: 0, width: 108, height: 108))
    }

    @Test func resizingAcrossTheAnchorKeepsTheAnchorStill() {
        var blurs = VideoBlurs(frame: frame)
        let id = blurs.add(CGRect(x: 100, y: 100, width: 200, height: 100), mode: .blur)!
        // The bottom-right corner dragged past the top-left: the box must not flip to the other side.
        blurs.resize(id, dragging: .bottomRight, to: CGPoint(x: 50, y: 50))
        #expect(blurs[id]?.rect == CGRect(x: 100, y: 100, width: 8, height: 8))
    }

    @Test func modeAndRemoval() {
        var blurs = VideoBlurs(frame: frame)
        let id = blurs.add(CGRect(x: 100, y: 100, width: 200, height: 100), mode: .blur)!
        blurs.setMode(.pixelate, of: id)
        #expect(blurs[id]?.mode == .pixelate)
        blurs.remove(id)
        #expect(blurs.isEmpty && blurs[id] == nil)
        blurs.remove(id)   // again: nothing happens
        #expect(blurs.regions.isEmpty)
    }
}
