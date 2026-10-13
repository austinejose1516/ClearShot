import CoreGraphics

/// Where the image sits on the export canvas: padding grows the canvas around it.
/// Annotations live in image pixels; `imageToCanvas` / `canvasToImage` convert.
public struct CanvasLayout: Equatable, Sendable {
    public let imageSize: CGSize
    public let canvasSize: CGSize
    public let imageRect: CGRect

    public init(imageSize: CGSize, frame: FrameStyle) {
        self.imageSize = imageSize
        let padding = max(0, frame.padding)
        canvasSize = CGSize(width: imageSize.width + 2 * padding, height: imageSize.height + 2 * padding)
        imageRect = CGRect(origin: CGPoint(x: padding, y: padding), size: imageSize)
    }

    public func imageToCanvas(_ point: CGPoint) -> CGPoint {
        CGPoint(x: imageRect.minX + point.x, y: imageRect.minY + point.y)
    }

    public func canvasToImage(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - imageRect.minX, y: point.y - imageRect.minY)
    }
}
