/// What a key press means in the Uploads window. The window maps keys itself: a menu-bar app has no Edit menu.
public enum UploadsCommand: Equatable, Sendable {
    case selectAll, copyLink, delete, open, clear
    case move(UploadSelection.Direction)

    /// `key` is the character without modifiers; `command` whether ⌘ was down. Nil when the key means nothing here.
    public init?(key: String, keyCode: UInt16, command: Bool) {
        if command {
            switch key.lowercased() {
            case "a": self = .selectAll
            case "c": self = .copyLink
            default: return nil
            }
        } else {
            switch keyCode {
            case 51, 117: self = .delete        // Backspace, Forward Delete
            case 36, 76: self = .open           // Return, keypad Enter
            case 53: self = .clear              // Esc
            case 123: self = .move(.left)
            case 124: self = .move(.right)
            case 126: self = .move(.up)
            case 125: self = .move(.down)
            default: return nil
            }
        }
    }
}
