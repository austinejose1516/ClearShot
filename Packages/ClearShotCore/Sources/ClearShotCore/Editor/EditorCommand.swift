/// Everything the editor's keyboard shortcuts and toolbar buttons can ask for, in one list. Copy, Share and
/// Upload live on the card, not here: the editor only hands its result back to the card (Done).
public enum EditorCommand: Equatable, Sendable {
    case undo, redo, delete, done, selectAll, cancel, confirm, zoomIn, zoomOut
    /// ⌘Return while typing: a new line in the text instead of finishing it.
    case newLine
    /// ⌘B, ⌘I, ⌘U: flip the text style, also while typing.
    case bold, italic, underline

    /// The command for a key press in the editor window, or nil to let the system handle it.
    /// `key` is the character without modifiers; key codes cover Delete, Esc and Return.
    /// While text is being typed, every key belongs to the text field except ⌘Return and the style keys.
    public init?(key: String, keyCode: UInt16, command: Bool, shift: Bool, editingText: Bool = false) {
        let isReturn = keyCode == 36 || keyCode == 76
        if editingText {
            guard command else { return nil }
            if isReturn {
                self = .newLine
            } else if let style = EditorCommand(styleKey: key, shift: shift) {
                self = style
            } else {
                return nil
            }
            return
        }
        if command {
            if let style = EditorCommand(styleKey: key, shift: shift) {
                self = style
                return
            }
            switch (key.lowercased(), shift) {
            case ("z", false): self = .undo
            case ("z", true): self = .redo
            case ("s", false): self = .done
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

    private init?(styleKey key: String, shift: Bool) {
        guard !shift else { return nil }
        switch key.lowercased() {
        case "b": self = .bold
        case "i": self = .italic
        case "u": self = .underline
        default: return nil
        }
    }
}
