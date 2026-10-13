import Foundation
import Observation

public enum ImageFormat: String, CaseIterable, Sendable, Codable {
    case png, jpeg

    public var fileExtension: String {
        switch self {
        case .png: "png"
        case .jpeg: "jpg"
        }
    }

    /// The format a file should be written in, from its extension. Nil for anything else.
    public init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "png": self = .png
        case "jpg", "jpeg": self = .jpeg
        default: return nil
        }
    }
}

/// User preferences, backed by UserDefaults. One instance per app, created by AppDelegate.
@Observable
public final class AppSettings {
    public static let defaultSaveFolder = FileManager.default
        .homeDirectoryForCurrentUser
        .appending(path: "Pictures/ScreenshotXX", directoryHint: .isDirectory)

    private enum Key {
        static let saveFolder = "saveFolderPath"
        static let imageFormat = "imageFormat"
        static let copiesToClipboard = "copiesToClipboard"
        static let showsCursor = "showsCursor"
        static let playsSound = "playsSound"
        static let cardAutoCloseSeconds = "cardAutoCloseSeconds"
        static let appearance = "appearance"
        static let accent = "accent"
        static let checksForUpdates = "checksForUpdates"
        static let lastUpdateCheck = "lastUpdateCheck"
    }

    @ObservationIgnored private let defaults: UserDefaults

    public var saveFolder: URL { didSet { defaults.set(saveFolder.path(), forKey: Key.saveFolder) } }
    public var imageFormat: ImageFormat { didSet { defaults.set(imageFormat.rawValue, forKey: Key.imageFormat) } }
    public var copiesToClipboard: Bool { didSet { defaults.set(copiesToClipboard, forKey: Key.copiesToClipboard) } }
    public var showsCursor: Bool { didSet { defaults.set(showsCursor, forKey: Key.showsCursor) } }
    public var playsSound: Bool { didSet { defaults.set(playsSound, forKey: Key.playsSound) } }
    /// 0 means the Quick Access card stays until closed.
    public var cardAutoCloseSeconds: Int { didSet { defaults.set(cardAutoCloseSeconds, forKey: Key.cardAutoCloseSeconds) } }
    public var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) } }
    public var accent: AccentTheme { didSet { defaults.set(accent.rawValue, forKey: Key.accent) } }
    /// Look for a newer release once a day.
    public var checksForUpdates: Bool { didSet { defaults.set(checksForUpdates, forKey: Key.checksForUpdates) } }
    public var lastUpdateCheck: Date? {
        didSet {
            if let lastUpdateCheck { defaults.set(lastUpdateCheck, forKey: Key.lastUpdateCheck) } else { defaults.removeObject(forKey: Key.lastUpdateCheck) }
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        saveFolder = defaults.string(forKey: Key.saveFolder)
            .map { URL(filePath: $0, directoryHint: .isDirectory) } ?? Self.defaultSaveFolder
        imageFormat = defaults.string(forKey: Key.imageFormat).flatMap(ImageFormat.init(rawValue:)) ?? .png
        copiesToClipboard = defaults.object(forKey: Key.copiesToClipboard) as? Bool ?? true
        showsCursor = defaults.object(forKey: Key.showsCursor) as? Bool ?? false
        playsSound = defaults.object(forKey: Key.playsSound) as? Bool ?? true
        cardAutoCloseSeconds = defaults.object(forKey: Key.cardAutoCloseSeconds) as? Int ?? 0
        appearance = defaults.string(forKey: Key.appearance).flatMap(Appearance.init(rawValue:)) ?? .system
        accent = defaults.string(forKey: Key.accent).flatMap(AccentTheme.init(rawValue:)) ?? .ocean
        checksForUpdates = defaults.object(forKey: Key.checksForUpdates) as? Bool ?? true
        lastUpdateCheck = defaults.object(forKey: Key.lastUpdateCheck) as? Date
    }
}
