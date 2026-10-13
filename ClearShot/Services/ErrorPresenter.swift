import AppKit

enum ErrorPresenter {
    static func show(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        WindowPresenter.becomeRegularApp()
        alert.runModal()
        WindowPresenter.returnToMenuBarIfNoWindows()
    }
}
