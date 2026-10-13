/// Everything the editor's keyboard shortcuts and toolbar buttons can ask for, in one list.
public enum EditorCommand: Equatable, Sendable {
    case undo, redo, delete, copy, save, saveAs, selectAll, cancel, confirm, zoomIn, zoomOut
    /// ⌘Return while typing: a new line in the text instead of finishing it.
    case newLine

    /// The command for a key press in the editor window, or nil to let the system handle it.
    /// `key` is the character without modifiers; key codes cover Delete, Esc and Return.
    /// While text is being typed, every key belongs to the text field except ⌘Return.
    public init?(key: String, keyCode: UInt16, command: Bool, shift: Bool, editingText: Bool = false) {
        let isReturn = keyCode == 36 || keyCode == 76
        if editingText {
            guard command, isReturn else { return nil }
            self = .newLine
            return
        }
        if command {
            switch (key.lowercased(), shift) {
            case ("z", false): self = .undo
            case ("z", true): self = .redo
            case ("c", false): self = .copy
            case ("s", false): self = .save
            case ("s", true): self = .saveAs
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
