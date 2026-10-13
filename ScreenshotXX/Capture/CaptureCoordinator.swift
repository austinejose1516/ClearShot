import Foundation
import os
import ScreenshotXXCore

@Observable
final class CaptureCoordinator {
    private let settings: AppSettings
    @ObservationIgnored private let log = Logger(subsystem: "com.austinejose.screenshotxx", category: "capture")

    init(settings: AppSettings) {
        self.settings = settings
    }

    func capture(_ kind: CaptureKind) {
        log.notice("capture requested: \(kind.rawValue, privacy: .public)")
    }
}
