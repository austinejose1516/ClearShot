import AppKit
import ClearShotCore
import SwiftUI

/// The Uploads window, opened from the menu bar (Uploads…) and from Settings → Cloud. One window; every
/// show lists the bucket again, and closing it lets the pictures go.
final class UploadsWindowController: NSWindowController, NSWindowDelegate {
    private let model: UploadsModel

    init(settings: AppSettings) {
        model = UploadsModel(settings: settings)
        let window = UploadsWindow(
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
        window.onCommand = { [model] in model.perform($0) }
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

/// A menu-bar app has no Edit menu, so the window turns key presses (⌘A, ⌘C, Delete, Return, Esc, the arrows)
/// into commands itself, before any view sees them. Keys go on as usual while a text field is being edited.
final class UploadsWindow: NSWindow {
    var onCommand: ((UploadsCommand) -> Void)?

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown, !(firstResponder is NSTextView) else {
            super.sendEvent(event)
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.isSubset(of: [.command, .numericPad, .function]),
              let command = UploadsCommand(key: event.charactersIgnoringModifiers ?? "", keyCode: event.keyCode,
                                           command: flags.contains(.command)) else {
            super.sendEvent(event)
            return
        }
        onCommand?(command)
    }
}
