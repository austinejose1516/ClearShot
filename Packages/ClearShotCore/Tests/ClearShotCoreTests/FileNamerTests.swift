import Foundation
import Testing
@testable import ClearShotCore

@Suite struct FileNamerTests {
    private let dublin = TimeZone(identifier: "Europe/Dublin")!

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = dublin
        return calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }

    @Test func nameUsesDateThenTimeWithDots() {
        let at = date(2026, 10, 13, 9, 41, 12)
        #expect(FileNamer.fileName(date: at, format: .png, timeZone: dublin) == "ClearShot 2026-10-13 at 09.41.12.png")
        #expect(FileNamer.fileName(date: at, format: .jpeg, timeZone: dublin) == "ClearShot 2026-10-13 at 09.41.12.jpg")
    }

    @Test func uniqueNameAddsCounterOnlyWhenTaken() {
        let taken: Set<String> = ["shot.png", "shot (2).png"]
        #expect(FileNamer.uniqueFileName("shot.png", exists: { taken.contains($0) }) == "shot (3).png")
        #expect(FileNamer.uniqueFileName("other.png", exists: { taken.contains($0) }) == "other.png")
    }
}
