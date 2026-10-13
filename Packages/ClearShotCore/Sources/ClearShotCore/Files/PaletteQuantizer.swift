import CoreGraphics
import Foundation

/// An image reduced to at most 256 colours, ready to become a palette PNG.
public struct PaletteImage: Sendable {
    public struct Color: Hashable, Sendable {
        public var r: UInt8, g: UInt8, b: UInt8, a: UInt8
    }

    public let width: Int
    public let height: Int
    /// At most 256 entries. See-through ones come first: a PNG's transparency table only covers a prefix.
    public let palette: [Color]
    /// One palette index per pixel, row by row, top row first.
    public let indices: [UInt8]
    /// How far the palette is from the original, on average, per channel (0…255). 0 when nothing was lost.
    public let error: Double
    /// The image's colour profile, so the file shows the same colours (Display P3 on a Mac).
    public let iccProfile: Data?
}

/// Reduces an image to 256 colours: as it is when it already has that few (nothing lost), otherwise median cut
/// (split the colours into 256 groups, use each group's average) and light dithering when repainting, so
/// gradients do not show bands. Works on byte buffers; a 4K screen takes well under half a second in release.
public enum PaletteQuantizer {
    public static let maxColors = 256
    /// Past this many distinct colours the image is a photo, not a screenshot; give up early.
    public static let colorCountCap = 100_000
    /// A palette that drifts more than this on average (about 1.8 % per channel) is not good enough; the caller
    /// keeps the normal PNG. Real screenshots score 1.5–2.5; photos score 20 and more.
    public static let maxError: Double = 4.5

    /// Nil when the image cannot be read or has far too many colours (a photo).
    public static func quantize(_ image: CGImage) -> PaletteImage? {
        guard let pixels = straightRGBA(image) else { return nil }
        let width = image.width, height = image.height
        let count = width * height
        guard count > 0 else { return nil }

        // Count the distinct colours; stop as soon as there are clearly too many.
        var histogram: [UInt32: Int] = [:]
        histogram.reserveCapacity(4096)
        var overflow = false
        pixels.withUnsafeBytes { raw in
            let words = raw.bindMemory(to: UInt32.self)
            for word in words {
                histogram[word, default: 0] += 1
                if histogram.count > colorCountCap {
                    overflow = true
                    break
                }
            }
        }
        guard !overflow else { return nil }
        let icc = image.colorSpace?.copyICCData() as Data?

        if histogram.count <= maxColors {
            // Lossless: the palette is exactly the colours that are there (in a fixed order, so the same image
            // always gives the same file).
            let palette = histogram.keys.map(Color.init(packed:)).sorted { ($0.a, $0.packed) < ($1.a, $1.packed) }
            var slot: [UInt32: UInt8] = [:]
            for (index, color) in palette.enumerated() { slot[color.packed] = UInt8(index) }
            var indices = [UInt8](repeating: 0, count: count)
            pixels.withUnsafeBytes { raw in
                let words = raw.bindMemory(to: UInt32.self)
                for i in 0..<count { indices[i] = slot[words[i]]! }
            }
            return PaletteImage(width: width, height: height, palette: palette, indices: indices, error: 0, iccProfile: icc)
        }

        // Sorted, so the result does not depend on the dictionary's order and the same image gives the same file.
        let entries = histogram.map { Entry(color: Color(packed: $0.key), count: $0.value) }.sorted { $0.color.packed < $1.color.packed }
        let palette = MedianCut.palette(of: entries, size: maxColors).sorted { ($0.a, $0.packed) < ($1.a, $1.packed) }
        let lookup = NearestColor(palette: palette)
        let error = fidelity(of: entries, lookup: lookup)
        let indices = Dither.repaint(pixels, width: width, height: height, lookup: lookup)
        return PaletteImage(width: width, height: height, palette: palette, indices: indices, error: error, iccProfile: icc)
    }

    /// Straight (not premultiplied) RGBA bytes, top row first, in the image's own colour space.
    static func straightRGBA(_ image: CGImage) -> [UInt8]? {
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return nil }
        let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        // Undo the premultiplication, so a half-transparent red is stored as red at 50 %, not dark red.
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let a = Int(pixels[i + 3])
            if a == 255 { continue }
            if a == 0 {
                pixels[i] = 0; pixels[i + 1] = 0; pixels[i + 2] = 0
                continue
            }
            for c in 0..<3 { pixels[i + c] = UInt8(min(255, (Int(pixels[i + c]) * 255 + a / 2) / a)) }
        }
        return pixels
    }

    /// The histogram's colours each matched to their nearest palette entry: the mean distance per channel.
    static func fidelity(of entries: [Entry], lookup: NearestColor) -> Double {
        var total = 0.0, weight = 0.0
        for entry in entries {
            let nearest = lookup.palette[Int(lookup.index(of: entry.color))]
            let distance = abs(Int(entry.color.r) - Int(nearest.r)) + abs(Int(entry.color.g) - Int(nearest.g))
                + abs(Int(entry.color.b) - Int(nearest.b)) + abs(Int(entry.color.a) - Int(nearest.a))
            total += Double(distance) * Double(entry.count)
            weight += Double(entry.count)
        }
        return weight > 0 ? total / weight / 4 : 0
    }

    struct Entry {
        let color: Color
        let count: Int
    }

    typealias Color = PaletteImage.Color
}

extension PaletteImage.Color {
    /// The byte order of the pixel buffer: R, G, B, A.
    init(packed: UInt32) {
        let bytes = withUnsafeBytes(of: packed.littleEndian) { Array($0) }
        self.init(r: bytes[0], g: bytes[1], b: bytes[2], a: bytes[3])
    }

    var packed: UInt32 {
        UInt32(r) | UInt32(g) << 8 | UInt32(b) << 16 | UInt32(a) << 24
    }

    subscript(channel: Int) -> UInt8 {
        switch channel {
        case 0: r
        case 1: g
        case 2: b
        default: a
        }
    }
}

/// Median cut: keep splitting the group of colours with the widest spread at its median until there are
/// `size` groups; each group's weighted average is one palette colour.
enum MedianCut {
    private struct Box {
        var entries: [PaletteQuantizer.Entry]
        var ranges: [Int]   // per channel, max - min
        var widest: Int { ranges.indices.max { ranges[$0] < ranges[$1] } ?? 0 }
        var spread: Int { ranges.max() ?? 0 }

        init(entries: [PaletteQuantizer.Entry]) {
            self.entries = entries
            ranges = (0..<4).map { channel in
                let values = entries.map { Int($0.color[channel]) }
                return (values.max() ?? 0) - (values.min() ?? 0)
            }
        }

        var average: PaletteImage.Color {
            var sums = [0, 0, 0, 0], weight = 0
            for entry in entries {
                for c in 0..<4 { sums[c] += Int(entry.color[c]) * entry.count }
                weight += entry.count
            }
            guard weight > 0 else { return .init(r: 0, g: 0, b: 0, a: 0) }
            return .init(r: UInt8(sums[0] / weight), g: UInt8(sums[1] / weight), b: UInt8(sums[2] / weight), a: UInt8(sums[3] / weight))
        }
    }

    static func palette(of entries: [PaletteQuantizer.Entry], size: Int) -> [PaletteImage.Color] {
        refine(split(entries, size: size), entries: entries, rounds: 3)
    }

    /// A few rounds of "move each palette colour to the average of the colours it is nearest to". A box's
    /// average can miss the flat colour that fills it by a shade; this snaps it back, so flat areas stay flat
    /// and the dithering has nothing to spread there.
    static func refine(_ palette: [PaletteImage.Color], entries: [PaletteQuantizer.Entry], rounds: Int) -> [PaletteImage.Color] {
        var palette = palette
        for _ in 0..<rounds {
            let lookup = NearestColor(palette: palette)
            var sums = [[Int]](repeating: [0, 0, 0, 0], count: palette.count)
            var weights = [Int](repeating: 0, count: palette.count)
            for entry in entries {
                let index = Int(lookup.index(of: entry.color))
                for c in 0..<4 { sums[index][c] += Int(entry.color[c]) * entry.count }
                weights[index] += entry.count
            }
            for i in palette.indices where weights[i] > 0 {
                let w = weights[i]
                palette[i] = .init(r: UInt8((sums[i][0] + w / 2) / w), g: UInt8((sums[i][1] + w / 2) / w),
                                   b: UInt8((sums[i][2] + w / 2) / w), a: UInt8((sums[i][3] + w / 2) / w))
            }
        }
        return palette
    }

    private static func split(_ entries: [PaletteQuantizer.Entry], size: Int) -> [PaletteImage.Color] {
        var boxes = [Box(entries: entries)]
        while boxes.count < size {
            // The box with the widest colour range splits next; stop when nothing is left to split.
            guard let index = boxes.indices.filter({ boxes[$0].entries.count > 1 }).max(by: { boxes[$0].spread < boxes[$1].spread }),
                  boxes[index].spread > 0 else { break }
            let box = boxes.remove(at: index)
            let channel = box.widest
            let sorted = box.entries.sorted { $0.color[channel] < $1.color[channel] }
            let total = sorted.reduce(0) { $0 + $1.count }
            var running = 0, cut = 0
            for (i, entry) in sorted.enumerated() {
                running += entry.count
                if running * 2 >= total {
                    cut = i + 1
                    break
                }
            }
            cut = min(max(cut, 1), sorted.count - 1)
            boxes.append(Box(entries: Array(sorted[..<cut])))
            boxes.append(Box(entries: Array(sorted[cut...])))
        }
        return boxes.map(\.average)
    }
}

/// Finds the closest palette entry, remembering the answer for every colour it has seen (5 bits per channel),
/// so a full screen costs a few thousand real searches, not millions.
final class NearestColor {
    let palette: [PaletteImage.Color]
    private var cache: [Int16]

    init(palette: [PaletteImage.Color]) {
        self.palette = palette
        cache = [Int16](repeating: -1, count: 1 << 20)
    }

    func index(of color: PaletteImage.Color) -> UInt8 {
        let key = Int(color.r >> 3) << 15 | Int(color.g >> 3) << 10 | Int(color.b >> 3) << 5 | Int(color.a >> 3)
        if cache[key] >= 0 { return UInt8(cache[key]) }
        let found = search(color)
        cache[key] = Int16(found)
        return found
    }

    private func search(_ color: PaletteImage.Color) -> UInt8 {
        var best = 0, bestDistance = Int.max
        for (i, entry) in palette.enumerated() {
            let dr = Int(entry.r) - Int(color.r), dg = Int(entry.g) - Int(color.g)
            let db = Int(entry.b) - Int(color.b), da = Int(entry.a) - Int(color.a)
            let distance = dr * dr + dg * dg + db * db + da * da
            if distance < bestDistance {
                bestDistance = distance
                best = i
            }
        }
        return UInt8(best)
    }
}

/// Repaints with the palette, spreading each pixel's rounding error over its neighbours (Floyd–Steinberg, at
/// half strength so flat areas stay clean) so gradients do not turn into bands.
enum Dither {
    static func repaint(_ pixels: [UInt8], width: Int, height: Int, lookup: NearestColor) -> [UInt8] {
        var indices = [UInt8](repeating: 0, count: width * height)
        // Error carried into the current and next row, 4 channels per pixel, with one spare pixel each side.
        var current = [Int](repeating: 0, count: (width + 2) * 4)
        var next = [Int](repeating: 0, count: (width + 2) * 4)
        for y in 0..<height {
            for x in 0..<width {
                let p = (y * width + x) * 4
                let e = (x + 1) * 4
                var wanted = [0, 0, 0, 0]
                for c in 0..<4 { wanted[c] = min(255, max(0, Int(pixels[p + c]) + current[e + c] / 16)) }
                let color = PaletteImage.Color(r: UInt8(wanted[0]), g: UInt8(wanted[1]), b: UInt8(wanted[2]), a: UInt8(wanted[3]))
                let index = lookup.index(of: color)
                indices[y * width + x] = index
                let chosen = lookup.palette[Int(index)]
                for c in 0..<4 {
                    // Half of the error moves on: 7/16 right, 3/16 down-left, 5/16 down, 1/16 down-right.
                    let error = (wanted[c] - Int(chosen[c])) / 2
                    current[e + 4 + c] += error * 7
                    next[e - 4 + c] += error * 3
                    next[e + c] += error * 5
                    next[e + 4 + c] += error * 1
                }
            }
            swap(&current, &next)
            for i in next.indices { next[i] = 0 }
        }
        return indices
    }
}
