import Foundation
import Testing
@testable import ScreenshotXXCore

@Suite struct DiagnosticLogTests {
    @Test func appendsTimestampedLines() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "diag-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: file) }

        DiagnosticLog.write("first", to: file)
        DiagnosticLog.write("second", to: file)

        let lines = try String(contentsOf: file, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].hasSuffix(" first"))
        #expect(lines[1].hasSuffix(" second"))
        #expect(lines[0].count > " first".count + 10) // has a timestamp prefix
    }
}
