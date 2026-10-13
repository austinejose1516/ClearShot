import Combine
import SwiftUI

/// First-run window: who we are, and the one permission the app needs.
struct PermissionOnboardingView: View {
    @State private var granted = PermissionService.hasScreenRecordingAccess
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            BrandHeader(iconSize: 72)
            HStack(spacing: 8) {
                Badge(text: "Free")
                Badge(text: "Open source")
                Badge(text: "No account")
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("One permission to start").font(.headline)
                Text("macOS needs your OK before any app can capture the screen. Without it, captures come back empty.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                step(1, "Click **Allow Access**, then turn on ScreenshotXX in System Settings.")
                step(2, "Quit ScreenshotXX from the menu bar and open it again.")
                step(3, "Press **⌃⇧A** to capture an area.")
            }
            .padding(16)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Label(granted ? "Access granted" : "Not granted yet",
                      systemImage: granted ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(granted ? .green : .secondary)
                Spacer()
                Button("Open System Settings") { PermissionService.openScreenRecordingSettings() }
                if granted {
                    Button("Done") { onDone() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Allow Access") { PermissionService.requestScreenRecordingAccess() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(28)
        .frame(width: 500)
        .onReceive(poll) { _ in granted = PermissionService.hasScreenRecordingAccess }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 20, height: 20)
                .background(Color.accentColor, in: Circle())
                .foregroundStyle(.white)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
