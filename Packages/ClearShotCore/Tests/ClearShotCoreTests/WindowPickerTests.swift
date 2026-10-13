import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct WindowPickerTests {
    private func window(_ id: UInt32, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                        bundle: String = "com.example.app", layer: Int = 0, onScreen: Bool = true) -> WindowInfo {
        WindowInfo(id: id, frame: CGRect(x: x, y: y, width: w, height: h), title: "W\(id)",
                   ownerBundleID: bundle, layer: layer, isOnScreen: onScreen)
    }

    @Test func candidatesDropOurOwnAndNonStandardWindows() {
        let windows = [
            window(1, 0, 0, 800, 600),
            window(2, 0, 0, 800, 600, bundle: "com.austinejose.clearshot"),
            window(3, 0, 0, 800, 600, layer: 25),
            window(4, 0, 0, 800, 600, onScreen: false),
            window(5, 0, 0, 49, 49),
            window(6, 10, 10, 50, 50),
        ]
        let kept = WindowPicker.candidates(windows, excludingBundleID: "com.austinejose.clearshot")
        #expect(kept.map(\.id) == [1, 6])
    }

    @Test func frontMostWindowUnderPointWins() {
        let back = window(1, 0, 0, 1000, 1000)
        let front = window(2, 100, 100, 300, 300)
        let candidates = [front, back] // SCK order: front to back
        #expect(WindowPicker.window(at: CGPoint(x: 150, y: 150), in: candidates)?.id == 2)
        #expect(WindowPicker.window(at: CGPoint(x: 900, y: 900), in: candidates)?.id == 1)
        #expect(WindowPicker.window(at: CGPoint(x: 1500, y: 1500), in: candidates) == nil)
    }

    @Test func windowsOutsideEveryScreenAreDropped() {
        let screens = [CGRect(x: 0, y: 0, width: 1800, height: 1169)]
        let windows = [window(1, 100, 100, 800, 600), window(2, -269, 697, 193, 173), window(3, 1700, 1100, 300, 300)]
        let kept = WindowPicker.candidates(windows, excludingBundleID: "x", screens: screens)
        #expect(kept.map(\.id) == [1, 3])
    }
}
