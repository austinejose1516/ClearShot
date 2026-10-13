import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import ClearShotCore

/// Smaller PNG files: 256 colours when that looks the same, the normal PNG otherwise.
@Suite struct SmallerPNGTests {
    private let p3 = CGColorSpace(name: CGColorSpace.displayP3)!

    private func image(_ width: Int, _ height: Int, draw: (CGContext) -> Void) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: p3, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        draw(context)
        return context.makeImage()!
    }

    private func decode(_ png: Data) -> CGImage {
        CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithData(png as CFData, nil)!, 0, nil)!
    }

    private func colourType(_ png: Data) -> UInt8 { png[25] }

    private func chunks(_ png: Data) -> [String] {
        var names: [String] = []
        var i = 8
        while i + 8 <= png.count {
            let length = Int(png[i]) << 24 | Int(png[i + 1]) << 16 | Int(png[i + 2]) << 8 | Int(png[i + 3])
            names.append(String(decoding: png[(i + 4)..<(i + 8)], as: UTF8.self))
            i += 12 + length
        }
        return names
    }

    /// A few flat colours, a half-see-through red and see-through corners: nothing to lose.
    private var fewColours: CGImage {
        image(64, 64) { c in
            c.setFillColor(CGColor(colorSpace: p3, components: [1, 1, 1, 1])!)
            c.fill(CGRect(x: 8, y: 8, width: 48, height: 48))
            c.setFillColor(CGColor(colorSpace: p3, components: [0.2, 0.4, 0.9, 1])!)
            c.fill(CGRect(x: 16, y: 16, width: 20, height: 20))
            c.setFillColor(CGColor(colorSpace: p3, components: [0.1, 0.1, 0.1, 1])!)
            c.fill(CGRect(x: 40, y: 16, width: 8, height: 30))
            c.setFillColor(CGColor(colorSpace: p3, components: [1, 0, 0, 0.5])!)
            c.fill(CGRect(x: 0, y: 0, width: 64, height: 6))
        }
    }

    /// Flat panels, thin anti-aliased "text" lines and a small gradient: many colours, like a real screenshot.
    private var screenshotLike: CGImage {
        image(400, 300) { c in
            c.setFillColor(CGColor(colorSpace: p3, components: [0.96, 0.96, 0.97, 1])!)
            c.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
            c.setFillColor(CGColor(colorSpace: p3, components: [1, 1, 1, 1])!)
            c.fill(CGRect(x: 20, y: 20, width: 360, height: 200))
            c.setFillColor(CGColor(colorSpace: p3, components: [0.23, 0.51, 0.96, 1])!)
            c.fill(CGRect(x: 30, y: 240, width: 120, height: 36))
            // Lines of "text": thin anti-aliased strokes over most of the picture, as in a real window.
            c.setStrokeColor(CGColor(colorSpace: p3, components: [0.12, 0.12, 0.14, 1])!)
            c.setLineWidth(1.3)
            for row in 0..<15 {
                for column in 0..<58 {
                    let x = 24 + CGFloat(column) * 6.1, y = 26 + CGFloat(row) * 12.3
                    c.move(to: CGPoint(x: x, y: y))
                    c.addLine(to: CGPoint(x: x + 3.4 + CGFloat(column % 3), y: y + 7.1 - CGFloat(row % 2)))
                }
            }
            c.strokePath()
            let gradient = CGGradient(colorsSpace: p3, colors: [CGColor(colorSpace: p3, components: [0.2, 0.4, 0.9, 1])!,
                                                                CGColor(colorSpace: p3, components: [0.3, 0.5, 1, 1])!] as CFArray,
                                      locations: [0, 1])!
            c.saveGState()
            c.clip(to: CGRect(x: 200, y: 240, width: 160, height: 36))
            c.drawLinearGradient(gradient, start: CGPoint(x: 200, y: 240), end: CGPoint(x: 360, y: 240), options: [])
            c.restoreGState()
        }
    }

    private func noise(_ width: Int, _ height: Int) -> CGImage {
        var state: UInt64 = 42
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for i in bytes.indices {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            bytes[i] = i % 4 == 3 ? 255 : UInt8(truncatingIfNeeded: state >> 33)
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: p3, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    @Test func fewColoursComeBackPixelForPixel() throws {
        let original = fewColours
        let quantized = try #require(PaletteQuantizer.quantize(original))
        #expect(quantized.error == 0)
        #expect(quantized.palette.count == 5)
        let standard = try FileSaver.encode(original, format: .png)
        let small = try #require(FileSaver.smallerPNG(original, standard: standard))
        #expect(colourType(small) == 3)
        #expect(small.count < standard.count)
        let before = try #require(PaletteQuantizer.straightRGBA(original))
        let after = try #require(PaletteQuantizer.straightRGBA(decode(small)))
        #expect(before.count == after.count)
        for i in stride(from: 0, to: before.count, by: 4) {
            let alpha = before[i + 3]
            let tolerance = alpha == 255 || alpha == 0 ? 0 : 2   // a half-see-through pixel rounds twice on the way back
            for c in 0..<4 { #expect(abs(Int(before[i + c]) - Int(after[i + c])) <= tolerance) }
        }
    }

    @Test func aScreenshotLikeImageGetsMuchSmallerAndStaysTrue() throws {
        let original = screenshotLike
        let quantized = try #require(PaletteQuantizer.quantize(original))
        #expect(quantized.palette.count == 256)
        #expect(quantized.error <= PaletteQuantizer.maxError, "error \(quantized.error)")
        let standard = try FileSaver.encode(original, format: .png)
        let palette = try #require(PalettePNG.encode(quantized))
        #expect(Double(palette.count) <= Double(standard.count) * 0.5, "palette \(palette.count) bytes vs standard \(standard.count)")
        let small = try #require(FileSaver.smallerPNG(original, standard: standard))
        #expect(small == palette)
        #expect(try FileSaver.encode(original, format: .png, smaller: true) == small)
    }

    @Test func photosFallBackToTheNormalPNG() throws {
        // Far too many colours: the quantizer gives up at once.
        let big = noise(400, 300)
        #expect(PaletteQuantizer.quantize(big) == nil)
        let standard = try FileSaver.encode(big, format: .png)
        #expect(FileSaver.smallerPNG(big, standard: standard) == nil)
        #expect(try FileSaver.encode(big, format: .png, smaller: true) == standard)
        // Under the cap, but 256 colours cannot stand in for 40,000: the quality check says no.
        let medium = noise(200, 200)
        let quantized = try #require(PaletteQuantizer.quantize(medium))
        #expect(quantized.error > PaletteQuantizer.maxError, "error \(quantized.error)")
        #expect(FileSaver.smallerPNG(medium, standard: try FileSaver.encode(medium, format: .png)) == nil)
    }

    @Test func transparentCornersAndSoftShadowsSurvive() throws {
        // A window-like box with a soft shadow on a see-through background: hundreds of alpha levels.
        let original = image(200, 160) { c in
            c.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: CGColor(colorSpace: p3, components: [0, 0, 0, 0.5])!)
            c.setFillColor(CGColor(colorSpace: p3, components: [0.95, 0.95, 0.96, 1])!)
            c.fill(CGRect(x: 40, y: 40, width: 120, height: 90))
        }
        let quantized = try #require(PaletteQuantizer.quantize(original))
        #expect(quantized.error <= PaletteQuantizer.maxError)
        let small = try #require(PalettePNG.encode(quantized))
        #expect(chunks(small).contains("tRNS"))
        let after = try #require(PaletteQuantizer.straightRGBA(decode(small)))
        let width = 200
        func alpha(_ x: Int, _ y: Int) -> UInt8 { after[(y * width + x) * 4 + 3] }
        #expect(alpha(0, 0) == 0 && alpha(199, 0) == 0 && alpha(0, 159) == 0 && alpha(199, 159) == 0)
        #expect(alpha(100, 80) == 255)
        // The shadow below the box is neither fully see-through nor solid.
        let underneath = alpha(100, 135)
        #expect(underneath > 0 && underneath < 255)
    }

    @Test func theColourProfileIsKept() throws {
        let original = fewColours
        let quantized = try #require(PaletteQuantizer.quantize(original))
        let small = try #require(PalettePNG.encode(quantized))
        #expect(chunks(small).contains("iCCP"))
        let decoded = decode(small)
        #expect(decoded.colorSpace?.copyICCData() as Data? == original.colorSpace?.copyICCData() as Data?)
    }

    @Test func thePNGPiecesAreRight() {
        #expect(CRC32.checksum(Data("IEND".utf8)) == 0xAE42_6082)
        #expect(Adler32.checksum(Data("Wikipedia".utf8)) == 0x11E6_0398)
        let text = Data(String(repeating: "ClearShot writes palette PNGs. ", count: 50).utf8)
        let stream = PalettePNG.zlib(text)!
        #expect(stream.count < text.count)
        #expect(stream[0] == 0x78 && stream[1] == 0x9C)
        let signature = Data(repeating: 0, count: 8)
        #expect(chunks(signature + PalettePNG.chunk("IEND", Data())) == ["IEND"])
    }
}
