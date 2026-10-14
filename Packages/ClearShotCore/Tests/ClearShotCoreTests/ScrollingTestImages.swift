import CoreGraphics
import Foundation

/// An 8-bit grey image where `pixel(x, y)` gives each value. Row 0 is the top row.
func greyImage(width: Int, height: Int, pixel: (Int, Int) -> UInt8) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    let data = context.data!.assumingMemoryBound(to: UInt8.self)
    for y in 0..<height {
        for x in 0..<width {
            data[y * context.bytesPerRow + x] = pixel(x, y)
        }
    }
    return context.makeImage()!
}

/// A grey image `width` wide where row i is filled with `values[i]`.
func rowImage(_ values: [UInt8], width: Int = 8) -> CGImage {
    greyImage(width: width, height: values.count) { _, y in values[y] }
}

/// The red channel of the leftmost pixel of every row, top to bottom (any colour space in).
func leftColumn(of image: CGImage) -> [UInt8] {
    let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                            bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let data = context.data!.assumingMemoryBound(to: UInt8.self)
    return (0..<image.height).map { data[$0 * context.bytesPerRow] }
}
