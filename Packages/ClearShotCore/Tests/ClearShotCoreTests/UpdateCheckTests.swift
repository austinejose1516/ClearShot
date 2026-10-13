import Foundation
import Testing
@testable import ClearShotCore

@Suite struct UpdateCheckTests {
    @Test func versionsParseWithOrWithoutAV() {
        #expect(AppVersion("v0.2.0") == AppVersion("0.2.0"))
        #expect(AppVersion("1.10") == AppVersion("1.10.0"))
        #expect(AppVersion("nonsense") == nil)
    }

    @Test func versionsCompareNumberByNumber() {
        #expect(AppVersion("0.10.0")! > AppVersion("0.9.9")!)
        #expect(AppVersion("1.0.0")! > AppVersion("0.99.0")!)
        #expect((AppVersion("0.2.0")! > AppVersion("0.2")!) == false)
    }

    @Test func aNewerTagIsAnUpdate() {
        #expect(UpdateCheck.result(current: "0.2.0", latestTag: "v0.3.0") == .available("0.3.0"))
        #expect(UpdateCheck.result(current: "0.2.0", latestTag: "v0.2.0") == .upToDate)
        #expect(UpdateCheck.result(current: "0.3.0", latestTag: "v0.2.0") == .upToDate)
        #expect(UpdateCheck.result(current: "0.2.0", latestTag: "beta") == .upToDate)
    }

    @Test func aCheckIsDueOncePerDay() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(UpdateCheck.isDue(lastCheck: nil, now: now))
        #expect(UpdateCheck.isDue(lastCheck: now.addingTimeInterval(-23 * 3600), now: now) == false)
        #expect(UpdateCheck.isDue(lastCheck: now.addingTimeInterval(-25 * 3600), now: now))
    }
}
