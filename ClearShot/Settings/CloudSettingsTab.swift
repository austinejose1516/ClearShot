import ClearShotCore
import SwiftUI

/// Settings → Cloud: the Cloudflare R2 bucket that Upload sends to. Fill in the details and press Connect;
/// once a test upload works, the details lock and Upload is on. Disconnect unlocks them.
struct CloudSettingsTab: View {
    @Environment(AppSettings.self) private var settings
    @State private var secret = KeychainStore.read(KeychainStore.r2Secret) ?? ""
    @State private var isConnecting = false
    @State private var problem: String?

    var body: some View {
        @Bindable var settings = settings
        Form {
            if settings.cloudConnected {
                Section {
                    LabeledContent("Account ID", value: settings.cloudAccountID)
                    LabeledContent("Access Key ID", value: settings.cloudAccessKeyID)
                    LabeledContent("Secret Access Key", value: String(repeating: "•", count: 14))
                    LabeledContent("Bucket", value: settings.cloudBucket)
                    LabeledContent("Public URL", value: settings.cloudPublicURL)
                } header: {
                    Text("Cloudflare R2")
                } footer: {
                    Text("Upload in the editor and on the card sends to this bucket and copies the link.")
                }

                Section {
                    LabeledContent("Status") {
                        HStack(spacing: 8) {
                            if secret.isEmpty {
                                Label("The secret is missing from the Keychain. Disconnect, then connect again.",
                                      systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                            Spacer(minLength: 8)
                            Button("Show Uploads") { (NSApp.delegate as? AppDelegate)?.showUploads() }
                            Button("Disconnect") { settings.cloudConnected = false }
                        }
                    }
                } footer: {
                    Text("Disconnect to change the details. Files already uploaded stay online.")
                }
            } else {
                Section {
                    TextField("Account ID", text: $settings.cloudAccountID)
                    TextField("Access Key ID", text: $settings.cloudAccessKeyID)
                    SecureField("Secret Access Key", text: $secret)
                    TextField("Bucket", text: $settings.cloudBucket)
                    TextField("Public URL", text: $settings.cloudPublicURL, prompt: Text("https://pub-….r2.dev or your own domain"))
                } header: {
                    Text("Cloudflare R2")
                } footer: {
                    Text("In the Cloudflare dashboard: R2 → Manage API tokens → create a token with Object Read & Write for the bucket. It shows the Access Key ID and the Secret Access Key; the Account ID is on the same page. The Public URL is under the bucket's Settings → Public access (an r2.dev address or your own domain). The secret is kept in your Keychain.")
                }
                .autocorrectionDisabled()
                .onChange(of: settings.cloud) { _, _ in problem = nil }
                .onChange(of: secret) { _, _ in problem = nil }

                Section {
                    LabeledContent("Status") {
                        HStack(spacing: 8) {
                            if isConnecting {
                                ProgressView().controlSize(.small)
                                Text("Connecting…").foregroundStyle(.secondary)
                            } else if let problem {
                                Label(problem, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("Not connected").foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Button("Connect", action: connect)
                                .buttonStyle(.borderedProminent)
                                .disabled(isConnecting || !settings.cloud.isComplete || secret.isEmpty)
                        }
                    }
                } footer: {
                    Text("Connect uploads a tiny file, opens it through the Public URL, then deletes it. If that works, the details lock and Upload is ready.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 470)
    }

    private func connect() {
        guard let uploader = R2Uploader(config: settings.cloud, secretAccessKey: secret) else {
            problem = R2Failure.badSettings.localizedDescription
            return
        }
        problem = nil
        isConnecting = true
        Task {
            defer { isConnecting = false }
            do {
                try await uploader.test()
                KeychainStore.write(secret, account: KeychainStore.r2Secret)
                settings.cloudConnected = true
            } catch {
                problem = error.localizedDescription
            }
        }
    }
}
