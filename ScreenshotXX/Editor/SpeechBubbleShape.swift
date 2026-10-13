import SwiftUI

/// Rounded box with a tail that points at `tail`, drawn as one continuous outline
/// (no path union, so it cannot flicker while the tail is dragged).
struct SpeechBubbleShape: Shape {
    let box: CGRect
    let tail: CGPoint

    nonisolated func path(in rect: CGRect) -> Path {
        let b = box.standardized
        let r = min(24, min(b.width, b.height) * 0.2)
        var path = Path()

        // Which edge the tail leaves from: the one it is furthest beyond. Inside the box → no tail.
        let beyondX = tail.x < b.minX ? b.minX - tail.x : (tail.x > b.maxX ? tail.x - b.maxX : 0)
        let beyondY = tail.y < b.minY ? b.minY - tail.y : (tail.y > b.maxY ? tail.y - b.maxY : 0)
        let edge: Int? = (beyondX <= 0 && beyondY <= 0) ? nil : (beyondX > beyondY ? (tail.x < b.minX ? 3 : 1) : (tail.y < b.minY ? 0 : 2))
        let half = max(6, min(min(b.width, b.height) * 0.14, (min(b.width, b.height) - 2 * r) / 2 - 1))
        let baseX = min(max(tail.x, b.minX + r + half), b.maxX - r - half)
        let baseY = min(max(tail.y, b.minY + r + half), b.maxY - r - half)

        path.move(to: CGPoint(x: b.minX + r, y: b.minY))
        if edge == 0 {
            path.addLine(to: CGPoint(x: baseX - half, y: b.minY)); path.addLine(to: tail); path.addLine(to: CGPoint(x: baseX + half, y: b.minY))
        }
        path.addLine(to: CGPoint(x: b.maxX - r, y: b.minY))
        path.addQuadCurve(to: CGPoint(x: b.maxX, y: b.minY + r), control: CGPoint(x: b.maxX, y: b.minY))
        if edge == 1 {
            path.addLine(to: CGPoint(x: b.maxX, y: baseY - half)); path.addLine(to: tail); path.addLine(to: CGPoint(x: b.maxX, y: baseY + half))
        }
        path.addLine(to: CGPoint(x: b.maxX, y: b.maxY - r))
        path.addQuadCurve(to: CGPoint(x: b.maxX - r, y: b.maxY), control: CGPoint(x: b.maxX, y: b.maxY))
        if edge == 2 {
            path.addLine(to: CGPoint(x: baseX + half, y: b.maxY)); path.addLine(to: tail); path.addLine(to: CGPoint(x: baseX - half, y: b.maxY))
        }
        path.addLine(to: CGPoint(x: b.minX + r, y: b.maxY))
        path.addQuadCurve(to: CGPoint(x: b.minX, y: b.maxY - r), control: CGPoint(x: b.minX, y: b.maxY))
        if edge == 3 {
            path.addLine(to: CGPoint(x: b.minX, y: baseY + half)); path.addLine(to: tail); path.addLine(to: CGPoint(x: b.minX, y: baseY - half))
        }
        path.addLine(to: CGPoint(x: b.minX, y: b.minY + r))
        path.addQuadCurve(to: CGPoint(x: b.minX + r, y: b.minY), control: CGPoint(x: b.minX, y: b.minY))
        path.closeSubpath()
        return path
    }
}
