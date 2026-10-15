import Foundation
import Testing
@testable import ClearShotCore

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
        #expect(settings.saveFolder.path().hasSuffix("/Desktop/"))
        #expect(settings.imageFormat == .png)
        #expect(settings.keepsFilesSmall == true)
        #expect(settings.copiesToClipboard == true)
        #expect(settings.showsCursor == false)
        #expect(settings.playsSound == true)
        #expect(settings.cardAutoCloseSeconds == 0)
        #expect(settings.appearance == .system)
        #expect(settings.accent == .ocean)
        #expect(settings.checksForUpdates == true)
        #expect(settings.lastUpdateCheck == nil)
        #expect(settings.cloud == R2Config())
        #expect(settings.cloud.isComplete == false)
        #expect(settings.cloudConnected == false)
        #expect(settings.videoQuality == .smaller)
        #expect(settings.recordsMicrophone == true)
        #expect(settings.recordsSystemAudio == true)
        #expect(settings.recordingShowsPointer == true)
        #expect(settings.recordingShowsClicks == true)
        #expect(settings.microphoneID == nil)
    }

    @Test func cloudSettingsPersistWithoutTheSecret() {
        let (defaults, cleanup) = freshDefaults()
        defer { cleanup() }
        let first = AppSettings(defaults: defaults)
        first.cloudAccountID = "abc123"
        first.cloudAccessKeyID = "key"
        first.cloudBucket = "shots"
        first.cloudPublicURL = "https://pub-abc.r2.dev"
        first.cloudConnected = true
        let second = AppSettings(defaults: defaults)
        #expect(second.cloud == R2Config(accountID: "abc123", accessKeyID: "key", bucket: "shots", publicURL: "https://pub-abc.r2.dev"))
        #expect(second.cloud.isComplete)
        #expect(second.cloudConnected)
    }

    @Test func changesPersistAcrossInstances() {
        let (defaults, cleanup) = freshDefaults()
        defer { cleanup() }

        let first = AppSettings(defaults: defaults)
        first.imageFormat = .jpeg
        first.keepsFilesSmall = false
        first.copiesToClipboard = false
        first.showsCursor = true
        first.playsSound = false
        first.cardAutoCloseSeconds = 15
        first.saveFolder = URL(filePath: "/tmp/shots", directoryHint: .isDirectory)
        first.appearance = .dark
        first.accent = .sunset
        first.checksForUpdates = false
        first.lastUpdateCheck = Date(timeIntervalSince1970: 1_800_000_000)
        first.videoQuality = .retina
        first.recordsMicrophone = false
        first.recordsSystemAudio = false
        first.recordingShowsPointer = false
        first.recordingShowsClicks = false
        first.microphoneID = "BuiltInMicrophoneDevice"

        let second = AppSettings(defaults: defaults)
        #expect(second.imageFormat == .jpeg)
        #expect(second.keepsFilesSmall == false)
        #expect(second.copiesToClipboard == false)
        #expect(second.showsCursor == true)
        #expect(second.playsSound == false)
        #expect(second.cardAutoCloseSeconds == 15)
        #expect(second.saveFolder.path() == "/tmp/shots/")
        #expect(second.appearance == .dark)
        #expect(second.accent == .sunset)
        #expect(second.checksForUpdates == false)
        #expect(second.lastUpdateCheck == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(second.videoQuality == .retina)
        #expect(second.recordsMicrophone == false)
        #expect(second.recordsSystemAudio == false)
        #expect(second.recordingShowsPointer == false)
        #expect(second.recordingShowsClicks == false)
        #expect(second.microphoneID == "BuiltInMicrophoneDevice")
    }

    @Test func clearingTheMicrophoneGoesBackToTheDefault() {
        let (defaults, cleanup) = freshDefaults()
        defer { cleanup() }
        let first = AppSettings(defaults: defaults)
        first.microphoneID = "AirPods"
        first.microphoneID = nil
        #expect(AppSettings(defaults: defaults).microphoneID == nil)
    }

    @Test func jpegFilesUseJpgExtension() {
        #expect(ImageFormat.jpeg.fileExtension == "jpg")
        #expect(ImageFormat.png.fileExtension == "png")
        #expect(ImageFormat.jpeg.mimeType == "image/jpeg")
        #expect(ImageFormat.png.mimeType == "image/png")
    }

    @Test func everyAccentHasItsOwnColourAndName() {
        let colours = AccentTheme.allCases.map(\.color)
        #expect(Set(colours).count == AccentTheme.allCases.count)
        #expect(AccentTheme.allCases.map(\.title) == ["Ocean", "Violet", "Sunset", "Forest", "Graphite"])
    }
}
