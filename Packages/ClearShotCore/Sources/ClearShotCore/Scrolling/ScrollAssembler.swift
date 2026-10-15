import CoreGraphics

/// Draws a stitcher's slices into one tall image.
public enum ScrollAssembler {
    /// Taller than this is cut off: about twenty screens, and still a sane PNG.
    public static let maxHeight = 30_000

    /// `frames` are the kept frames in order (see `ScrollStitcher`); `slices` say which rows of which frame go
    /// where; `columns`, when given, is the part of the frames that scrolled, and the page is only that wide.
    /// Nil when there is nothing to draw.
    public static func assemble(frames: [CGImage], slices: [ScrollStitcher.Slice], columns: Range<Int>? = nil) -> CGImage? {
        guard let first = frames.first, !slices.isEmpty else { return nil }
        let columns = (columns ?? 0..<first.width).clamped(to: 0..<first.width)
        let width = columns.count
        let total = min(maxHeight, slices.reduce(0) { $0 + $1.rows.count })
        guard width > 0, total > 0,
              let context = CGContext(data: nil, width: width, height: total, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        var y = 0
        for slice in slices {
            guard y < total, slice.frame < frames.count else { break }
            let height = min(slice.rows.count, total - y)
            guard let part = frames[slice.frame].cropping(to: CGRect(x: columns.lowerBound, y: slice.rows.lowerBound, width: width, height: height))
            else { break }
            // CGContext draws from the bottom-left corner; the page is built from the top.
            context.draw(part, in: CGRect(x: 0, y: total - y - height, width: width, height: height))
            y += height
        }
        return context.makeImage()
    }
}
