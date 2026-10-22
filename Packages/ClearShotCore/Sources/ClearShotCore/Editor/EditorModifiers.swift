/// Keys held while the mouse is pressed or moved in the editor.
public struct EditorModifiers: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// ⇧: a square or a circle while drawing, the same proportions while resizing, a line at the nearest 45°.
    public static let shift = EditorModifiers(rawValue: 1 << 0)
    /// ⌥: draw a new shape over (or inside) an existing one instead of picking it up.
    public static let option = EditorModifiers(rawValue: 1 << 1)
}
