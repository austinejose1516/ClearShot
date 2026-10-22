import Foundation
import Testing
@testable import ClearShotCore

@Suite struct CaptureBarModelTests {
    /// A throwaway UserDefaults domain so tests never touch the real app settings.
    private func freshDefaults() -> (UserDefaults, cleanup: () -> Void) {
        let name = "CaptureBarModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (defaults, { defaults.removePersistentDomain(forName: name) })
    }

    @Test func eachPickModeSaysWhatToDoAndWhatItMakes() {
        #expect(PickMode.area.hint == "Drag an area")
        #expect(PickMode.window.hint == "Click a window")
        #expect(PickMode.fullScreen.hint == "Click a screen")
        #expect(PickMode.area.kind == .area && PickMode.window.kind == .window && PickMode.fullScreen.kind == .fullScreen)
        #expect(CaptureAction.allCases.allSatisfy { !$0.title.isEmpty && !$0.symbol.isEmpty })
        #expect(PickMode.allCases.allSatisfy { !$0.title.isEmpty && !$0.symbol.isEmpty })
        #expect(CaptureAction.allCases.map(\.title) == ["Screenshot", "Scrolling", "Record"])
        #expect(PickMode.allCases.map(\.title) == ["Area", "Window", "Full screen"])
    }

    @Test func spaceTogglesAreaAndWindowAndLeavesFullScreenForArea() {
        #expect(PickMode.area.afterSpace == .window)
        #expect(PickMode.window.afterSpace == .area)
        #expect(PickMode.fullScreen.afterSpace == .area)
    }

    @Test func theBarRemembersWhatAndHowBetweenUses() {
        let (defaults, cleanup) = freshDefaults()
        defer { cleanup() }
        let settings = AppSettings(defaults: defaults)
        let first = CaptureBarModel.remembered(from: settings, action: .recording)
        #expect(first.action == .recording && first.pickMode == .area)
        #expect(first.hint == "Drag an area")
        first.pickMode = .fullScreen
        first.remember(in: settings)
        let next = CaptureBarModel.remembered(from: settings, action: nil)
        #expect(next.action == .recording && next.pickMode == .fullScreen)
        #expect(next.hint == "Click a screen")
        // A menu item picks what to make; how to pick stays remembered.
        let fromMenu = CaptureBarModel.remembered(from: settings, action: .screenshot)
        #expect(fromMenu.action == .screenshot && fromMenu.pickMode == .fullScreen)
    }
}
