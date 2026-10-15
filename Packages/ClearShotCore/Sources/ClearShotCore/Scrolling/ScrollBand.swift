import CoreGraphics

/// The part of a window that scrolls, found by comparing two frames: the columns where many rows changed. A
/// sidebar or a toolbar that stays put is left out, so rows can be matched (and the page assembled) from the
/// moving part alone. A blinking caret or a ticking clock changes too few rows to count.
public enum ScrollBand {
    /// A column moves when at least this share of its rows changed.
    public static let movingShare = 0.2
    /// The frames are compared at half size, which is plenty to find the columns and four times cheaper.
    private static let step = 2

    /// The moving columns, from the first to the last; nil when (almost) nothing moved.
    public static func columns(between first: CGImage, and second: CGImage) -> Range<Int>? {
        guard first.width == second.width, first.height == second.height,
              let a = grey(first), let b = grey(second), a.width == b.width else { return nil }
        let threshold = max(1, Int((Double(a.height) * movingShare).rounded(.up)))
        var moving: [Int] = []
        for x in 0..<a.width {
            var changed = 0
            for y in 0..<a.height where a.pixels[y * a.width + x] != b.pixels[y * b.width + x] {
                changed += 1
                if changed >= threshold { break }
            }
            if changed >= threshold { moving.append(x) }
        }
        guard let lowest = moving.first, let highest = moving.last else { return nil }
        return (lowest * step)..<min(first.width, (highest + 1) * step)
    }

    /// The image in grey levels at half size, row by row.
    private static func grey(_ image: CGImage) -> (pixels: [UInt8], width: Int, height: Int)? {
        let width = max(1, image.width / step)
        let height = max(1, image.height / step)
        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? (pixels, width, height) : nil
    }
}
