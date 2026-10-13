import AppKit
import KeyboardShortcuts
import ClearShotCore
import ServiceManagement
import SwiftUI

// MARK: - General

struct GeneralSettingsTab: View {
    @Environment(AppSettings.self) private var settings
    @Environment(UpdateChecker.self) private var updates
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                HStack {
                    BrandHeader(iconSize: 44, subtitle: AppInfo.version)
                    Spacer()
                    Badge(text: "Free")
                    Badge(text: "Open source")
                }
            }

            Section("Appearance") {
                Picker("Mode", selection: $settings.appearance) {
                    ForEach(Appearance.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Accent") {
                    HStack(spacing: 10) {
                        ForEach(AccentTheme.allCases, id: \.self) { accent in
                            Button { settings.accent = accent } label: {
                                Circle()
                                    .fill(Color(accent.color))
                                    .frame(width: 18, height: 18)
                                    .padding(3)
                                    .overlay(Circle().stroke(Color(accent.color), lineWidth: settings.accent == accent ? 2 : 0))
                            }
                            .buttonStyle(.plain)
                            .help(accent.title)
                        }
                        Text(settings.accent.title).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
                    }
                }
            }
            .onChange(of: settings.appearance) { _, appearance in Theme.apply(appearance) }

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

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $settings.checksForUpdates)
                LabeledContent("Last checked") {
                    HStack(spacing: 8) {
                        Text(settings.lastUpdateCheck.map { $0.formatted(.relative(presentation: .named)) } ?? "Never")
                            .foregroundStyle(.secondary)
                        Button("Check Now") { updates.checkNow() }
                    }
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
        .frame(width: 540, height: 760)
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

struct ShortcutsSettingsTab: View {
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
                Text("First turn off the built-in ones: System Settings → Keyboard → Keyboard Shortcuts → Screenshots. Then ClearShot takes over ⇧⌘3 (full screen), ⇧⌘4 (area) and ⇧⌘5 (window).")
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 330)
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

struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            VStack(spacing: 4) {
                Text(AppInfo.name).font(.largeTitle.bold())
                Text(AppInfo.version).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Badge(text: "Free")
                Badge(text: "Open source")
                Badge(text: "MIT licence")
            }
            Text("Capture, annotate and share screenshots. Free forever: the code is public on GitHub, and ideas, issues and pull requests are welcome.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button {
                    NSWorkspace.shared.open(AppInfo.repository)
                } label: {
                    Label("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    NSWorkspace.shared.open(AppInfo.issues)
                } label: {
                    Label("Report an issue", systemImage: "exclamationmark.bubble")
                }
            }
            Spacer()
            Text("© 2026 Austine Jose · MIT licence").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(width: 540, height: 470)
    }
}
