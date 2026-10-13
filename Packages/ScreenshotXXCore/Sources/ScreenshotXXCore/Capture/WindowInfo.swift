import CoreGraphics

/// What the picker needs to know about an on-screen window. `frame` is in Quartz coordinates (top-left origin, global).
public struct WindowInfo: Identifiable, Sendable, Equatable {
    public let id: UInt32
    public let frame: CGRect
    public let title: String?
    public let ownerBundleID: String?
    public let layer: Int
    public let isOnScreen: Bool

    public init(id: UInt32, frame: CGRect, title: String?, ownerBundleID: String?, layer: Int, isOnScreen: Bool) {
        self.id = id
        self.frame = frame
        self.title = title
        self.ownerBundleID = ownerBundleID
        self.layer = layer
        self.isOnScreen = isOnScreen
    }
}
