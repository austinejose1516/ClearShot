import AppKit
import KeyboardShortcuts
import ScreenshotXXCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }
            ShortcutsSettingsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 460)
        .padding()
    }
}

private struct GeneralSettingsTab: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            LabeledContent("Save to") {
                HStack {
                    Text(settings.saveFolder.path(percentEncoded: false))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Choose…") { chooseFolder() }
                }
            }
            Picker("Format", selection: $settings.imageFormat) {
                ForEach(ImageFormat.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
            }
            Toggle("Copy to clipboard after capture", isOn: $settings.copiesToClipboard)
            Toggle("Show mouse cursor", isOn: $settings.showsCursor)
            Toggle("Play shutter sound", isOn: $settings.playsSound)
            Stepper(value: $settings.cardAutoCloseSeconds, in: 0...120, step: 5) {
                Text(settings.cardAutoCloseSeconds == 0
                     ? "Keep card until closed"
                     : "Close card after \(settings.cardAutoCloseSeconds) s")
            }
            Toggle("Launch at login", isOn: Binding(
                get: { SMAppService.mainApp.status == .enabled },
                set: { on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        ErrorPresenter.show(title: "Could not change login item", message: error.localizedDescription)
                    }
                }))
            LabeledContent("Diagnostics") {
                Button("Show Log in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([DiagnosticLog.defaultFile])
                }
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = settings.saveFolder
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveFolder = url
        }
    }
}

private struct ShortcutsSettingsTab: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Capture area", name: .captureArea)
            KeyboardShortcuts.Recorder("Capture window", name: .captureWindow)
            KeyboardShortcuts.Recorder("Capture full screen", name: .captureFullScreen)
        }
    }
}
