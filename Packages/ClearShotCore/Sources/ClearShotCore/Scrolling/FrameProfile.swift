import CoreGraphics

/// A frame reduced to a few grey levels per pixel row: every row is kept, the width is shrunk to
/// `samplesPerRow`. Frames are compared row by row by how much their samples differ, not by whether they are
/// identical, so a page that sits between two pixels after a trackpad scroll, antialiasing that came out a
/// little differently, and a blinking caret all still look like the same rows.
public struct FrameProfile: Equatable, Sendable {
    /// Enough to tell one line of text from the next, and cheap to compare.
    public static let samplesPerRow = 128

    public let height: Int
    /// Samples per row: `samplesPerRow`, or fewer when the picture is narrower than that.
    public let width: Int
    /// `height × width` grey levels, row by row, top to bottom.
    public let samples: [UInt8]

    public init(height: Int, width: Int, samples: [UInt8]) {
        precondition(samples.count == height * width, "a profile needs height × width samples")
        self.height = height
        self.width = width
        self.samples = samples
    }

    public func row(_ index: Int) -> [UInt8] {
        Array(samples[(index * width)..<((index + 1) * width)])
    }

    /// How much row `a` of this frame differs from row `b` of `other`: the mean absolute difference of their
    /// samples, 0…255. The frames must be the same width.
    public func rowDistance(_ a: Int, to other: FrameProfile, _ b: Int) -> Int {
        guard width > 0, width == other.width else { return 255 }
        return samples.withUnsafeBufferPointer { mine in
            other.samples.withUnsafeBufferPointer { theirs in
                Self.rowDistance(mine, a, theirs, b, width: width) / width
            }
        }
    }

    /// How much two frames of the same size differ overall: the mean absolute difference of all samples, 0…255.
    public func distance(to other: FrameProfile) -> Double {
        guard height == other.height, width == other.width, !samples.isEmpty else { return 255 }
        let total = samples.withUnsafeBufferPointer { mine in
            other.samples.withUnsafeBufferPointer { theirs in
                (0..<height).reduce(0) { $0 + Self.rowDistance(mine, $1, theirs, $1, width: width) }
            }
        }
        return Double(total) / Double(samples.count)
    }

    /// The sum of absolute differences between one row of each buffer. The hot loop of the stitcher's search,
    /// on raw pointers so a debug build does not check bounds on every sample.
    static func rowDistance(_ a: UnsafeBufferPointer<UInt8>, _ aRow: Int, _ b: UnsafeBufferPointer<UInt8>, _ bRow: Int, width: Int) -> Int {
        guard let aBase = a.baseAddress, let bBase = b.baseAddress else { return 0 }
        var mine = aBase + aRow * width
        var theirs = bBase + bRow * width
        var total = 0
        for _ in 0..<width {
            total &+= abs(Int(mine.pointee) - Int(theirs.pointee))
            mine += 1
            theirs += 1
        }
        return total
    }

    /// The profile of `image`. `ignoringRightPixels` leaves out a strip at the right (the scrollbar).
    public static func of(_ image: CGImage, ignoringRightPixels: Int = 0) -> FrameProfile {
        of(image, columns: 0..<max(1, image.width - max(0, ignoringRightPixels)))
    }

    /// The profile of only these columns of `image` (the part of a window that scrolls; see `ScrollBand`).
    public static func of(_ image: CGImage, columns: Range<Int>) -> FrameProfile {
        let height = image.height
        let columns = columns.clamped(to: 0..<image.width)
        let width = min(samplesPerRow, columns.count)
        guard height > 0, width > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return FrameProfile(height: 0, width: 0, samples: []) }
        let kept = columns.count < image.width
            ? image.cropping(to: CGRect(x: columns.lowerBound, y: 0, width: columns.count, height: height)) ?? image
            : image
        // Scaled only sideways, with the pixels of each stretch averaged: the height is unchanged, so every
        // output row is exactly one input row.
        context.interpolationQuality = .high
        context.draw(kept, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return FrameProfile(height: 0, width: 0, samples: []) }
        let bytes = UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: width * height)
        return FrameProfile(height: height, width: width, samples: Array(bytes))
    }
}
