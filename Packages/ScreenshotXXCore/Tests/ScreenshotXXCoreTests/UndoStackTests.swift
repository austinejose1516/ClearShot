import Testing
@testable import ScreenshotXXCore

@Suite struct UndoStackTests {
    @Test func pushUndoRedoWalkHistory() {
        var stack = UndoStack(initial: 0)
        stack.push(1)
        stack.push(2)
        #expect(stack.undo() == 1)
        #expect(stack.undo() == 0)
        #expect(stack.undo() == nil)
        #expect(stack.redo() == 1)
        #expect(stack.canRedo)
        stack.push(5)
        #expect(stack.canRedo == false)
        #expect(stack.current == 5)
    }

    @Test func pushingTheSameStateIsIgnored() {
        var stack = UndoStack(initial: "a")
        stack.push("a")
        #expect(stack.canUndo == false)
    }

    @Test func limitDropsTheOldestStates() {
        var stack = UndoStack(initial: 0, limit: 2)
        stack.push(1); stack.push(2); stack.push(3)
        #expect(stack.undo() == 2)
        #expect(stack.undo() == 1)
        #expect(stack.undo() == nil)
    }
}
