import CoreGraphics

/// Where the image sits on the export canvas for a given frame.
/// Annotations live in image pixels; `imageToCanvas` / `canvasToImage` convert.
public struct CanvasLayout: Equatable, Sendable {
    public let imageSize: CGSize
    public let canvasSize: CGSize
    public let imageRect: CGRect
    public let imageScale: CGFloat

    public init(imageSize: CGSize, frame: FrameStyle) {
        self.imageSize = imageSize
        let padding = max(0, frame.padding)
        let inset = max(0, min(frame.inset, min(imageSize.width, imageSize.height) / 2 - 1))
        canvasSize = CGSize(width: imageSize.width + 2 * padding, height: imageSize.height + 2 * padding)
        imageRect = CGRect(x: padding + inset, y: padding + inset,
                           width: imageSize.width - 2 * inset, height: imageSize.height - 2 * inset)
        imageScale = imageRect.width / imageSize.width
    }

    public func imageToCanvas(_ point: CGPoint) -> CGPoint {
        CGPoint(x: imageRect.minX + point.x * imageScale, y: imageRect.minY + point.y * imageScale)
    }

    public func canvasToImage(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - imageRect.minX) / imageScale, y: (point.y - imageRect.minY) / imageScale)
    }
}
