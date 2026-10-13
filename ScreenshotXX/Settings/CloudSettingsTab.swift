import ScreenshotXXCore
import SwiftUI

/// Settings → Cloud: the Cloudflare R2 bucket that Upload sends to, and a Test button that proves the setup.
struct CloudSettingsTab: View {
    @Environment(AppSettings.self) private var settings
    @State private var secret = KeychainStore.read(KeychainStore.r2Secret) ?? ""
    @State private var secretSave: Task<Void, Never>?
    @State private var isTesting = false
    @State private var outcome: Outcome?

    private enum Outcome {
        case works
        case failed(String)
    }

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                TextField("Account ID", text: $settings.cloudAccountID)
                TextField("Access Key ID", text: $settings.cloudAccessKeyID)
                SecureField("Secret Access Key", text: $secret)
                    .onChange(of: secret) { _, value in saveSecret(value) }
                TextField("Bucket", text: $settings.cloudBucket)
                TextField("Public URL", text: $settings.cloudPublicURL, prompt: Text("https://pub-….r2.dev or your own domain"))
            } header: {
                Text("Cloudflare R2")
            } footer: {
                Text("In the Cloudflare dashboard: R2 → Manage API tokens → create a token with Object Read & Write for the bucket. It shows the Access Key ID and the Secret Access Key; the Account ID is on the same page. The Public URL is under the bucket's Settings → Public access (an r2.dev address or your own domain). The secret is kept in your Keychain.")
            }
            .autocorrectionDisabled()

            Section {
                LabeledContent("Setup") {
                    HStack(spacing: 8) {
                        if isTesting {
                            ProgressView().controlSize(.small)
                            Text("Testing…").foregroundStyle(.secondary)
                        } else {
                            outcomeText
                        }
                        Spacer(minLength: 8)
                        Button("Test", action: test)
                            .disabled(isTesting || !settings.cloud.isComplete || secret.isEmpty)
                    }
                }
            } footer: {
                Text("Test uploads a tiny file, opens it through the Public URL, then deletes it. Upload in the editor and on the card is on once this works.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 470)
    }

    @ViewBuilder private var outcomeText: some View {
        switch outcome {
        case .works:
            Label("Works. Links will open.", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        case nil:
            Text("Not tested yet").foregroundStyle(.secondary)
        }
    }

    /// Typing writes the Keychain once it pauses, not on every key.
    private func saveSecret(_ value: String) {
        outcome = nil
        secretSave?.cancel()
        secretSave = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            KeychainStore.write(value, account: KeychainStore.r2Secret)
        }
    }

    private func test() {
        guard let uploader = R2Uploader(config: settings.cloud, secretAccessKey: secret) else {
            outcome = .failed(R2Failure.badSettings.localizedDescription)
            return
        }
        KeychainStore.write(secret, account: KeychainStore.r2Secret)
        isTesting = true
        Task {
            defer { isTesting = false }
            do {
                try await uploader.test()
                outcome = .works
            } catch {
                outcome = .failed(error.localizedDescription)
            }
        }
    }
}
