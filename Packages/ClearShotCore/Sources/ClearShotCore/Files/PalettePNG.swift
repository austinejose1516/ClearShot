import Compression
import Foundation

/// Writes a palette PNG: the 256-colour list once, then one byte per pixel. Apple's ImageIO cannot write one
/// with transparency or keep the colour profile, so this does (PLTE, tRNS and iCCP chunks), with Apple's
/// Compression library doing the zip part.
public enum PalettePNG {
    public static func encode(_ image: PaletteImage) -> Data? {
        guard (1...256).contains(image.palette.count), image.indices.count == image.width * image.height else { return nil }
        var png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

        var header = Data()
        header.append(bigEndian: UInt32(image.width))
        header.append(bigEndian: UInt32(image.height))
        header.append(contentsOf: [8, 3, 0, 0, 0])   // 8 bits per index, palette colour, deflate, no filter, no interlace
        png.append(chunk("IHDR", header))

        if let icc = image.iccProfile, let zipped = zlib(icc) {
            png.append(chunk("iCCP", Data("ICC Profile".utf8) + [0, 0] + zipped))
        }

        var plte = Data(capacity: image.palette.count * 3)
        for color in image.palette { plte.append(contentsOf: [color.r, color.g, color.b]) }
        png.append(chunk("PLTE", plte))

        // The transparency table covers a prefix of the palette; entries after the last see-through one are opaque.
        if let last = image.palette.lastIndex(where: { $0.a < 255 }) {
            png.append(chunk("tRNS", Data(image.palette[...last].map(\.a))))
        }

        // Each row starts with a filter byte (0: none), then the indices.
        var rows = Data(capacity: (image.width + 1) * image.height)
        image.indices.withUnsafeBufferPointer { indices in
            for y in 0..<image.height {
                rows.append(0)
                rows.append(contentsOf: UnsafeBufferPointer(rebasing: indices[(y * image.width)..<((y + 1) * image.width)]))
            }
        }
        guard let idat = zlib(rows) else { return nil }
        png.append(chunk("IDAT", idat))
        png.append(chunk("IEND", Data()))
        return png
    }

    // MARK: - Pieces

    /// Length, type, data, CRC of type and data.
    static func chunk(_ type: String, _ data: Data) -> Data {
        var chunk = Data()
        chunk.append(bigEndian: UInt32(data.count))
        let typed = Data(type.utf8) + data
        chunk.append(typed)
        chunk.append(bigEndian: CRC32.checksum(typed))
        return chunk
    }

    /// A zlib stream: 2-byte header, raw deflate from Apple's Compression library, Adler-32 trailer.
    static func zlib(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        let capacity = data.count + data.count / 100 + 1024
        var compressed = Data(count: capacity)
        let written = compressed.withUnsafeMutableBytes { destination -> Int in
            data.withUnsafeBytes { source -> Int in
                compression_encode_buffer(destination.bindMemory(to: UInt8.self).baseAddress!, capacity,
                                          source.bindMemory(to: UInt8.self).baseAddress!, data.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { return nil }
        compressed.count = written
        var stream = Data([0x78, 0x9C])
        stream.append(compressed)
        stream.append(bigEndian: Adler32.checksum(data))
        return stream
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 == 1 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data { crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
        return crc ^ 0xFFFF_FFFF
    }
}

enum Adler32 {
    static func checksum(_ data: Data) -> UInt32 {
        var a: UInt32 = 1, b: UInt32 = 0
        data.withUnsafeBytes { bytes in
            for byte in bytes {
                a = (a + UInt32(byte)) % 65521
                b = (b + a) % 65521
            }
        }
        return b << 16 | a
    }
}

extension Data {
    mutating func append(bigEndian value: UInt32) {
        append(contentsOf: [UInt8(value >> 24), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)])
    }
}
