import Foundation
import Testing
@testable import ClearShotCore

@Suite struct ImageFormatTests {
    @Test func formatComesFromTheFileExtension() {
        #expect(ImageFormat(url: URL(filePath: "/tmp/shot.png")) == .png)
        #expect(ImageFormat(url: URL(filePath: "/tmp/shot.jpg")) == .jpeg)
        #expect(ImageFormat(url: URL(filePath: "/tmp/shot.JPEG")) == .jpeg)
        #expect(ImageFormat(url: URL(filePath: "/tmp/shot.gif")) == nil)
    }
}
