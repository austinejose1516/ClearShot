import AppKit
import Observation
import ScreenshotXXCore

/// Asks GitHub for the latest release.
/// - Menu → Check for Updates…: always answers, with an alert.
/// - Automatic (once a day, can be turned off): quiet; a newer version shows as a menu item instead of a pop-up.
@MainActor
@Observable
final class UpdateChecker {
    /// A newer version found by a check, shown in the menu.
    private(set) var availableVersion: String?
    @ObservationIgnored private var releasePage = AppInfo.releases
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var isChecking = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    func startAutomaticChecks() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkIfDue()
                try? await Task.sleep(for: .seconds(6 * 60 * 60))
            }
        }
    }

    func checkNow() {
        Task { await check(userAsked: true) }
    }

    func showAvailableUpdate() {
        guard let availableVersion else { return }
        showUpdate(version: availableVersion)
    }

    // MARK: - Checking

    private func checkIfDue() async {
        guard settings.checksForUpdates, UpdateCheck.isDue(lastCheck: settings.lastUpdateCheck, now: .now) else { return }
        await check(userAsked: false)
    }

    private func check(userAsked: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        do {
            let release = try await latestRelease()
            settings.lastUpdateCheck = .now
            releasePage = release.page
            switch UpdateCheck.result(current: AppInfo.shortVersion, latestTag: release.tag) {
            case .available(let version):
                availableVersion = version
                if userAsked { showUpdate(version: version) }
            case .upToDate:
                availableVersion = nil
                if userAsked { showUpToDate() }
            }
        } catch {
            DiagnosticLog.write("update check failed: \(error)")
            if userAsked { ErrorPresenter.show(title: "Could not check for updates", message: error.localizedDescription) }
        }
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlUrl: URL
    }

    private func latestRelease() async throws -> (tag: String, page: URL) {
        var request = URLRequest(url: AppInfo.latestReleaseAPI, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release = try decoder.decode(Release.self, from: data)
        return (release.tagName, release.htmlUrl)
    }

    // MARK: - Telling the user

    private var installedWithHomebrew: Bool {
        ["/opt/homebrew/Caskroom/screenshotxx", "/usr/local/Caskroom/screenshotxx"]
            .contains { FileManager.default.fileExists(atPath: $0) }
    }

    private func showUpdate(version: String) {
        let alert = NSAlert()
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "ScreenshotXX \(version) is available"
        let viaHomebrew = installedWithHomebrew
        if viaHomebrew {
            alert.informativeText = "You have \(AppInfo.shortVersion). To update, run this in Terminal, then open ScreenshotXX again:\n\n\(AppInfo.upgradeCommand)"
            alert.addButton(withTitle: "Copy Command")
            alert.addButton(withTitle: "What's New")
        } else {
            alert.informativeText = "You have \(AppInfo.shortVersion)."
            alert.addButton(withTitle: "Download")
        }
        alert.addButton(withTitle: "Later")
        WindowPresenter.becomeRegularApp()
        let response = alert.runModal()
        WindowPresenter.returnToMenuBarIfNoWindows()
        switch (viaHomebrew, response) {
        case (true, .alertFirstButtonReturn):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(AppInfo.upgradeCommand, forType: .string)
        case (true, .alertSecondButtonReturn), (false, .alertFirstButtonReturn):
            NSWorkspace.shared.open(releasePage)
        default:
            break
        }
    }

    private func showUpToDate() {
        let alert = NSAlert()
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "You're up to date"
        alert.informativeText = "ScreenshotXX \(AppInfo.shortVersion) is the newest version."
        WindowPresenter.becomeRegularApp()
        alert.runModal()
        WindowPresenter.returnToMenuBarIfNoWindows()
    }
}
