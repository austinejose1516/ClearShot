import CoreGraphics

/// The maths behind the trim bar: seconds along the recording map straight onto points along the bar.
public enum TrimBarGeometry {
    public static func x(forSeconds seconds: Double, width: CGFloat, total: Double) -> CGFloat {
        guard total > 0, width > 0 else { return 0 }
        return CGFloat(min(max(seconds, 0), total) / total) * width
    }

    public static func seconds(atX x: CGFloat, width: CGFloat, total: Double) -> Double {
        guard total > 0, width > 0 else { return 0 }
        return Double(min(max(x, 0), width) / width) * total
    }

    /// Where the filmstrip's pictures are taken from: the middle of each of `count` equal slices.
    public static func thumbnailTimes(count: Int, total: Double) -> [Double] {
        guard count > 0 else { return [] }
        return (0..<count).map { (Double($0) + 0.5) / Double(count) * total }
    }
}
