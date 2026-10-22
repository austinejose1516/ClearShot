import AppKit
import ClearShotCore
import SwiftUI

/// The Uploads window, opened from the menu bar (Uploads…) and from Settings → Cloud. One window; every
/// show lists the bucket again, and closing it lets the pictures go.
final class UploadsWindowController: NSWindowController, NSWindowDelegate {
    private let model: UploadsModel

    init(settings: AppSettings) {
        model = UploadsModel(settings: settings)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: UploadsView.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "Uploads"
        window.minSize = UploadsView.minimumSize
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        super.init(window: window)
        window.delegate = self
        let host = NSHostingController(rootView: UploadsView(model: model, onOpenCloudSettings: UploadService.openCloudSettings)
            .themed(settings))
        host.sizingOptions = .minSize
        window.contentViewController = host
        window.setContentSize(UploadsView.defaultSize)
        window.center()
        window.setFrameAutosaveName("Uploads")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    func show() {
        model.load()
        window.map(WindowPresenter.show)
    }

    func windowWillClose(_ notification: Notification) {
        model.clear()
    }
}
