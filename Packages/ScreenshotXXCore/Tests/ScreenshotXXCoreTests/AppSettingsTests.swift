import Foundation
import Testing
@testable import ScreenshotXXCore

@Suite struct AppSettingsTests {
    /// A throwaway UserDefaults domain so tests never touch the real app settings.
    private func freshDefaults() -> (UserDefaults, cleanup: () -> Void) {
        let name = "AppSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (defaults, { defaults.removePersistentDomain(forName: name) })
    }

    @Test func defaultsMatchSpec() {
        let (defaults, cleanup) = freshDefaults()
        defer { cleanup() }
        let settings = AppSettings(defaults: defaults)

        #expect(settings.saveFolder == AppSettings.defaultSaveFolder)
        #expect(settings.saveFolder.path().hasSuffix("/Pictures/ScreenshotXX/"))
        #expect(settings.imageFormat == .png)
        #expect(settings.copiesToClipboard == true)
        #expect(settings.showsCursor == false)
        #expect(settings.playsSound == true)
        #expect(settings.cardAutoCloseSeconds == 0)
        #expect(settings.appearance == .system)
        #expect(settings.accent == .ocean)
    }

    @Test func changesPersistAcrossInstances() {
        let (defaults, cleanup) = freshDefaults()
        defer { cleanup() }

        let first = AppSettings(defaults: defaults)
        first.imageFormat = .jpeg
        first.copiesToClipboard = false
        first.showsCursor = true
        first.playsSound = false
        first.cardAutoCloseSeconds = 15
        first.saveFolder = URL(filePath: "/tmp/shots", directoryHint: .isDirectory)
        first.appearance = .dark
        first.accent = .sunset

        let second = AppSettings(defaults: defaults)
        #expect(second.imageFormat == .jpeg)
        #expect(second.copiesToClipboard == false)
        #expect(second.showsCursor == true)
        #expect(second.playsSound == false)
        #expect(second.cardAutoCloseSeconds == 15)
        #expect(second.saveFolder.path() == "/tmp/shots/")
        #expect(second.appearance == .dark)
        #expect(second.accent == .sunset)
    }

    @Test func jpegFilesUseJpgExtension() {
        #expect(ImageFormat.jpeg.fileExtension == "jpg")
        #expect(ImageFormat.png.fileExtension == "png")
    }

    @Test func everyAccentHasItsOwnColourAndName() {
        let colours = AccentTheme.allCases.map(\.color)
        #expect(Set(colours).count == AccentTheme.allCases.count)
        #expect(AccentTheme.allCases.map(\.title) == ["Ocean", "Violet", "Sunset", "Forest", "Graphite"])
    }
}
