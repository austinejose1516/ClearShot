import AppKit
import ScreenshotXXCore

/// A menu-bar app has no Edit menu, so the window turns key presses into editor commands itself.
final class EditorWindow: NSWindow {
    var onCommand: ((EditorCommand) -> Void)?

    /// While the inline text field is focused, keys belong to it (except ⌘Return, a new line).
    private var textIsEditing: Bool { firstResponder is NSTextView }

    func insertNewLineInText() {
        (firstResponder as? NSTextView)?.insertNewlineIgnoringFieldEditor(nil)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command),
              let command = EditorCommand(key: event.charactersIgnoringModifiers ?? "", keyCode: event.keyCode,
                                          command: true, shift: flags.contains(.shift), editingText: textIsEditing) else {
            return super.performKeyEquivalent(with: event)
        }
        onCommand?(command)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard !textIsEditing,
              let command = EditorCommand(key: event.charactersIgnoringModifiers ?? "", keyCode: event.keyCode,
                                          command: false, shift: false) else {
            super.keyDown(with: event)
            return
        }
        onCommand?(command)
    }
}
