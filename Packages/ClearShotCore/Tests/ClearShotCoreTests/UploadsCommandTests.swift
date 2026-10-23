import Testing
@testable import ClearShotCore

@Suite struct UploadsCommandTests {
    @Test func commandKeys() {
        #expect(UploadsCommand(key: "a", keyCode: 0, command: true) == .selectAll)
        #expect(UploadsCommand(key: "c", keyCode: 8, command: true) == .copyLink)
        #expect(UploadsCommand(key: "a", keyCode: 0, command: false) == nil)
    }

    @Test func plainKeys() {
        #expect(UploadsCommand(key: "", keyCode: 51, command: false) == .delete)     // Backspace
        #expect(UploadsCommand(key: "", keyCode: 117, command: false) == .delete)    // Forward Delete
        #expect(UploadsCommand(key: "", keyCode: 36, command: false) == .open)       // Return
        #expect(UploadsCommand(key: "", keyCode: 53, command: false) == .clear)      // Esc
        #expect(UploadsCommand(key: "", keyCode: 123, command: false) == .move(.left))
        #expect(UploadsCommand(key: "", keyCode: 124, command: false) == .move(.right))
        #expect(UploadsCommand(key: "", keyCode: 126, command: false) == .move(.up))
        #expect(UploadsCommand(key: "", keyCode: 125, command: false) == .move(.down))
        #expect(UploadsCommand(key: "x", keyCode: 7, command: false) == nil)
    }
}
