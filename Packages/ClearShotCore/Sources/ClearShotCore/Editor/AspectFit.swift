import CoreGraphics

/// A picture scaled to fit inside a box (up or down), keeping its shape, centred.
public enum AspectFit {
    public static func rect(for size: CGSize, in box: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return CGRect(x: box.midX, y: box.midY, width: 0, height: 0) }
        let scale = min(box.width / size.width, box.height / size.height)
        let width = size.width * scale
        let height = size.height * scale
        return CGRect(x: box.midX - width / 2, y: box.midY - height / 2, width: width, height: height)
    }
}
