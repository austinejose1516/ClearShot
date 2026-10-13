import AppKit

/// Closures the window forwards keyboard shortcuts to. Set by the editor view.
final class EditorActions {
    var undo: (() -> Void)?
    var redo: (() -> Void)?
    var delete: (() -> Void)?
    var copy: (() -> Void)?
    var save: (() -> Void)?
    var selectAll: (() -> Void)?
    var deselect: (() -> Void)?
    var zoomIn: (() -> Void)?
    var zoomOut: (() -> Void)?
    var confirm: (() -> Void)?
}

/// A menu-bar app has no Edit menu, so the window handles the usual shortcuts itself.
final class EditorWindow: NSWindow {
    let actions = EditorActions()

    private var textIsEditing: Bool { firstResponder is NSTextView }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), !textIsEditing,
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }
        switch (key, flags.contains(.shift)) {
        case ("z", false): actions.undo?()
        case ("z", true): actions.redo?()
        case ("c", false): actions.copy?()
        case ("s", false): actions.save?()
        case ("a", false): actions.selectAll?()
        case ("=", _), ("+", _): actions.zoomIn?()
        case ("-", _): actions.zoomOut?()
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard !textIsEditing else { super.keyDown(with: event); return }
        switch event.keyCode {
        case 51, 117: actions.delete?()     // Backspace, Forward delete
        case 53: actions.deselect?()        // Esc
        case 36, 76: actions.confirm?()     // Return, Enter
        default: super.keyDown(with: event)
        }
    }
}
