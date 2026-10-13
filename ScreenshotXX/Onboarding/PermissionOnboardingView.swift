import Combine
import SwiftUI

struct PermissionOnboardingView: View {
    @State private var granted = PermissionService.hasScreenRecordingAccess
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("ScreenshotXX needs Screen Recording access")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("macOS asks for this once. Without it, every capture comes back black.\nAfter you allow it, quit and reopen ScreenshotXX.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Open System Settings") { PermissionService.openScreenRecordingSettings() }
                Button("Allow Access") { PermissionService.requestScreenRecordingAccess() }
                    .buttonStyle(.borderedProminent)
            }
            Label(granted ? "Access granted" : "Not granted yet",
                  systemImage: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(granted ? .green : .secondary)
            Button("Done") { onDone() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(width: 440)
        .onReceive(poll) { _ in granted = PermissionService.hasScreenRecordingAccess }
    }
}
