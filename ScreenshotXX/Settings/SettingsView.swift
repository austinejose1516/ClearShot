import AppKit
import KeyboardShortcuts
import ScreenshotXXCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            ShortcutsSettingsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 440)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @Environment(AppSettings.self) private var settings
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Saving") {
                LabeledContent("Folder") {
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(settings.saveFolder.path(percentEncoded: false)
                            .replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false), with: "~/"))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 8)
                        Button("Change…", action: chooseFolder)
                    }
                }
                Picker("Format", selection: $settings.imageFormat) {
                    Text("PNG").tag(ImageFormat.png)
                    Text("JPEG").tag(ImageFormat.jpeg)
                }
                .pickerStyle(.segmented)
            }

            Section("After a capture") {
                Toggle("Copy to the clipboard", isOn: $settings.copiesToClipboard)
                Toggle("Play the shutter sound", isOn: $settings.playsSound)
                Toggle("Include the mouse pointer", isOn: $settings.showsCursor)
                Picker("Card stays for", selection: $settings.cardAutoCloseSeconds) {
                    Text("Until closed").tag(0)
                    Text("10 seconds").tag(10)
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                }
            }

            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                LabeledContent("Diagnostics") {
                    Button("Show Log in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([DiagnosticLog.defaultFile])
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = settings.saveFolder
        panel.prompt = "Use this folder"
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveFolder = url
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            ErrorPresenter.show(title: "Could not change the login item", message: error.localizedDescription)
        }
    }
}

// MARK: - Shortcuts

private struct ShortcutsSettingsTab: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Capture area", name: .captureArea)
                KeyboardShortcuts.Recorder("Capture window", name: .captureWindow)
                KeyboardShortcuts.Recorder("Capture full screen", name: .captureFullScreen)
            } footer: {
                Text("In area mode, press Space to switch to window mode. Esc cancels.")
            }

            Section {
                LabeledContent("Use the macOS shortcuts") {
                    Button("Set ⇧⌘3 · ⇧⌘4 · ⇧⌘5") { useSystemShortcuts() }
                }
            } footer: {
                Text("First turn off the built-in ones: System Settings → Keyboard → Keyboard Shortcuts → Screenshots. Then ScreenshotXX takes over ⇧⌘3 (full screen), ⇧⌘4 (area) and ⇧⌘5 (window).")
            }
        }
        .formStyle(.grouped)
    }

    private func useSystemShortcuts() {
        KeyboardShortcuts.setShortcut(.init(.three, modifiers: [.shift, .command]), for: .captureFullScreen)
        KeyboardShortcuts.setShortcut(.init(.four, modifiers: [.shift, .command]), for: .captureArea)
        KeyboardShortcuts.setShortcut(.init(.five, modifiers: [.shift, .command]), for: .captureWindow)
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Shortcuts") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - About

private struct AboutSettingsTab: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("ScreenshotXX").font(.title2.bold())
            Text(version).foregroundStyle(.secondary)
            Text("Capture, annotate, share.").foregroundStyle(.secondary)
            Spacer()
            Text("© 2026 Austine Jose").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
