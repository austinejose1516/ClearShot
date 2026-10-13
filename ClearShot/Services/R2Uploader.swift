import Foundation
import ClearShotCore

/// Sends files to the Cloudflare R2 bucket from Settings → Cloud, with SigV4-signed S3 requests.
struct R2Uploader {
    let config: R2Config
    private let signer: SigV4Signer

    /// Nil until Settings → Cloud is complete and the secret is in the Keychain.
    init?(config: R2Config, secretAccessKey: String?) {
        guard config.isComplete, let secretAccessKey, !secretAccessKey.isEmpty else { return nil }
        self.config = config
        signer = SigV4Signer(accessKeyID: config.accessKeyID.trimmingCharacters(in: .whitespaces),
                             secretAccessKey: secretAccessKey, region: R2Config.region, service: R2Config.service)
    }

    /// What the editor and the card use: `nil` means "open Settings → Cloud first" (not connected there yet).
    static func fromSettings(_ settings: AppSettings) -> R2Uploader? {
        guard settings.cloudConnected else { return nil }
        return R2Uploader(config: settings.cloud, secretAccessKey: KeychainStore.read(KeychainStore.r2Secret))
    }

    /// Uploads the bytes under `key` (folder and file name, e.g. "images/k3x9p2m7qa.png") and returns the link.
    func upload(_ data: Data, contentType: String, key: String) async throws -> URL {
        guard let url = config.endpoint(key: key), let link = config.link(name: key) else { throw R2Failure.badSettings }
        _ = try await send("PUT", url, headers: ["Content-Type": contentType], body: data)
        return link
    }

    func delete(key: String) async throws {
        guard let url = config.endpoint(key: key) else { throw R2Failure.badSettings }
        _ = try await send("DELETE", url)
    }

    /// Proves the setup end to end: upload a tiny text file, fetch it through the Public URL, delete it.
    func test() async throws {
        let key = "clearshot-test-\(R2Name.stem()).txt"
        let body = Data("ClearShot can upload here.".utf8)
        let link = try await upload(body, contentType: "text/plain", key: key)
        let served = try? await fetchPublic(link)
        try await delete(key: key)
        guard served == body else { throw R2Failure.publicURLNotServing }
    }

    // MARK: - Requests

    private func send(_ method: String, _ url: URL, headers: [String: String] = [:], body: Data = Data()) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = method
        request.httpBody = body
        for (name, value) in signer.headers(for: .init(method: method, url: url, headers: headers, payload: body)) {
            request.setValue(value, forHTTPHeaderField: name)
        }
        let started = ContinuousClock.now
        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            DiagnosticLog.write("r2 \(method) \(url.lastPathComponent) failed: \(error.code.rawValue) \(error.localizedDescription)")
            throw Self.failure(for: error, host: url.host() ?? "")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        DiagnosticLog.write("r2 \(method) \(url.lastPathComponent): HTTP \(status), \(body.count) bytes, "
                            + "\((ContinuousClock.now - started).formatted(.units(allowed: [.milliseconds])))")
        guard (200..<300).contains(status) else { throw R2Response.failure(status: status, body: data) }
        return data
    }

    private func fetchPublic(_ link: URL) async throws -> Data {
        var request = URLRequest(url: link, timeoutInterval: 30)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw R2Failure.publicURLNotServing }
        return data
    }

    private static func failure(for error: URLError, host: String) -> R2Failure {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .internationalRoamingOff, .dataNotAllowed: .offline
        case .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost, .timedOut: .unreachable(host)
        default: .server(error.localizedDescription)
        }
    }
}
