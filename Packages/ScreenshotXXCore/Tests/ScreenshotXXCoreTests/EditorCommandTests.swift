import Testing
@testable import ScreenshotXXCore

@Suite struct EditorCommandTests {
    @Test func commandShortcuts() {
        #expect(EditorCommand(key: "z", keyCode: 6, command: true, shift: false) == .undo)
        #expect(EditorCommand(key: "Z", keyCode: 6, command: true, shift: true) == .redo)
        #expect(EditorCommand(key: "c", keyCode: 8, command: true, shift: false) == .copy)
        #expect(EditorCommand(key: "s", keyCode: 1, command: true, shift: false) == .save)
        #expect(EditorCommand(key: "S", keyCode: 1, command: true, shift: true) == .saveAs)
        #expect(EditorCommand(key: "a", keyCode: 0, command: true, shift: false) == .selectAll)
        #expect(EditorCommand(key: "=", keyCode: 24, command: true, shift: false) == .zoomIn)
        #expect(EditorCommand(key: "-", keyCode: 27, command: true, shift: false) == .zoomOut)
        #expect(EditorCommand(key: "q", keyCode: 12, command: true, shift: false) == nil)
    }

    @Test func plainKeys() {
        #expect(EditorCommand(key: "", keyCode: 51, command: false, shift: false) == .delete)
        #expect(EditorCommand(key: "", keyCode: 117, command: false, shift: false) == .delete)
        #expect(EditorCommand(key: "", keyCode: 53, command: false, shift: false) == .cancel)
        #expect(EditorCommand(key: "\r", keyCode: 36, command: false, shift: false) == .confirm)
        #expect(EditorCommand(key: "x", keyCode: 7, command: false, shift: false) == nil)
    }

    @Test func whileTypingOnlyCommandReturnIsOursAndItAddsANewLine() {
        #expect(EditorCommand(key: "\r", keyCode: 36, command: true, shift: false, editingText: true) == .newLine)
        #expect(EditorCommand(key: "\r", keyCode: 36, command: false, shift: false, editingText: true) == nil)
        #expect(EditorCommand(key: "z", keyCode: 6, command: true, shift: false, editingText: true) == nil)
        #expect(EditorCommand(key: "", keyCode: 51, command: false, shift: false, editingText: true) == nil)
    }
}
