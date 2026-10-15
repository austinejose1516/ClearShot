import CoreGraphics

/// One 64-bit hash per pixel row, so two frames can be compared row by row without keeping the pixels around.
public enum FrameSignature {
    /// The hashes of `image`'s rows, top to bottom, from its grey levels at a quarter of the width (enough to
    /// tell rows apart, cheap to make). `ignoringRightPixels` leaves out a strip at the right (the scrollbar).
    public static func rows(of image: CGImage, ignoringRightPixels: Int = 0) -> [UInt64] {
        rows(of: image, columns: 0..<max(1, image.width - max(0, ignoringRightPixels)))
    }

    /// The same, from only these columns (the part of a window that scrolls; see `ScrollBand`).
    public static func rows(of image: CGImage, columns: Range<Int>) -> [UInt64] {
        let height = image.height
        let columns = columns.clamped(to: 0..<image.width)
        let sampled = max(1, columns.count / 4)
        guard height > 0, !columns.isEmpty,
              let context = CGContext(data: nil, width: sampled, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return [] }
        let kept = columns.count < image.width
            ? image.cropping(to: CGRect(x: columns.lowerBound, y: 0, width: columns.count, height: height)) ?? image
            : image
        // Scaled only sideways: the height is unchanged, so every output row is exactly one input row.
        context.interpolationQuality = .low
        context.draw(kept, in: CGRect(x: 0, y: 0, width: sampled, height: height))
        guard let data = context.data else { return [] }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        let stride = context.bytesPerRow
        return (0..<height).map { row in fnv1a(bytes + row * stride, count: sampled) }
    }

    /// FNV-1a, 64-bit.
    static func fnv1a(_ bytes: UnsafePointer<UInt8>, count: Int) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for index in 0..<count {
            hash ^= UInt64(bytes[index])
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
