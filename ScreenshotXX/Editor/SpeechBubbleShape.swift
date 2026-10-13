import SwiftUI

/// Rounded box with a tail that points at `tail`, as one outline.
struct SpeechBubbleShape: Shape {
    let box: CGRect
    let tail: CGPoint

    nonisolated func path(in rect: CGRect) -> Path {
        let b = box.standardized
        let radius = min(24, min(b.width, b.height) * 0.2)
        let body = Path(roundedRect: b, cornerRadius: radius)
        guard !b.insetBy(dx: -2, dy: -2).contains(tail) else { return body }

        // The tail leaves from the edge nearest to its point.
        let baseWidth = max(12, min(b.width, b.height) * 0.28)
        let half = baseWidth / 2
        let distances: [(CGFloat, Int)] = [
            (abs(tail.y - b.minY), 0), (abs(tail.x - b.maxX), 1), (abs(tail.y - b.maxY), 2), (abs(tail.x - b.minX), 3),
        ]
        let edge = distances.min { $0.0 < $1.0 }!.1
        let a: CGPoint, c: CGPoint
        switch edge {
        case 0, 2:
            let y = edge == 0 ? b.minY : b.maxY
            let x = min(max(tail.x, b.minX + radius + half), b.maxX - radius - half)
            a = CGPoint(x: x - half, y: y); c = CGPoint(x: x + half, y: y)
        default:
            let x = edge == 1 ? b.maxX : b.minX
            let y = min(max(tail.y, b.minY + radius + half), b.maxY - radius - half)
            a = CGPoint(x: x, y: y - half); c = CGPoint(x: x, y: y + half)
        }
        var triangle = Path()
        triangle.move(to: a)
        triangle.addLine(to: tail)
        triangle.addLine(to: c)
        triangle.closeSubpath()
        return body.union(triangle)
    }
}
