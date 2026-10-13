import Testing
@testable import ClearShotCore

@Suite struct EditorLifetimeTests {
    @Test func anOpenWindowIsNeverReleased() {
        #expect(EditorLifetime.shouldRelease(windowIsOpen: true, hasUnsavedEdits: false, cardIsOpen: false) == false)
    }

    @Test func aClosedWindowWithoutEditsIsReleased() {
        #expect(EditorLifetime.shouldRelease(windowIsOpen: false, hasUnsavedEdits: false, cardIsOpen: true) == true)
    }

    @Test func unsavedEditsAreKeptWhileTheCardCanStillReopenThem() {
        #expect(EditorLifetime.shouldRelease(windowIsOpen: false, hasUnsavedEdits: true, cardIsOpen: true) == false)
        #expect(EditorLifetime.shouldRelease(windowIsOpen: false, hasUnsavedEdits: true, cardIsOpen: false) == true)
    }
}
