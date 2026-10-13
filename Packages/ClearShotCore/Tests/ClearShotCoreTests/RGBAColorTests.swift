import Testing
@testable import ClearShotCore

@Suite struct RGBAColorTests {
    @Test func withAlphaKeepsTheColourAndChangesOnlyAlpha() {
        let faded = RGBAColor.blue.withAlpha(0.5)
        #expect(faded.alpha == 0.5)
        #expect(faded.sameColor(as: .blue))
        #expect(faded.sameColor(as: .red) == false)
    }
}
