/// Everything the editor's keyboard shortcuts and toolbar buttons can ask for, in one list.
public enum EditorCommand: Equatable, Sendable {
    case undo, redo, delete, copy, save, selectAll, cancel, confirm, zoomIn, zoomOut

    /// The command for a key press in the editor window, or nil to let the system handle it.
    /// `key` is the character without modifiers; key codes cover Delete, Esc and Return.
    public init?(key: String, keyCode: UInt16, command: Bool, shift: Bool) {
        if command {
            switch (key.lowercased(), shift) {
            case ("z", false): self = .undo
            case ("z", true): self = .redo
            case ("c", false): self = .copy
            case ("s", false): self = .save
            case ("a", false): self = .selectAll
            case ("=", _), ("+", _): self = .zoomIn
            case ("-", _): self = .zoomOut
            default: return nil
            }
        } else {
            switch keyCode {
            case 51, 117: self = .delete    // Backspace, Forward Delete
            case 53: self = .cancel         // Esc
            case 36, 76: self = .confirm    // Return, Enter
            default: return nil
            }
        }
    }
}
