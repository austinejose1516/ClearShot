import CryptoKit
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
    /// `progress` gets the fraction sent so far, off the main thread.
    func upload(_ data: Data, contentType: String, key: String, progress: (@Sendable (Double) -> Void)? = nil) async throws -> URL {
        guard let url = config.endpoint(key: key), let link = config.link(name: key) else { throw R2Failure.badSettings }
        _ = try await send("PUT", url, headers: ["Content-Type": contentType], body: .data(data), progress: progress)
        return link
    }

    /// The same for a file on disk (a recording): hashed in chunks and streamed from disk, so a long video
    /// never sits in memory.
    func upload(file: URL, contentType: String, key: String, progress: (@Sendable (Double) -> Void)? = nil) async throws -> URL {
        guard let url = config.endpoint(key: key), let link = config.link(name: key) else { throw R2Failure.badSettings }
        let hash = try await Task.detached { try Self.sha256Hex(ofFile: file) }.value
        _ = try await send("PUT", url, headers: ["Content-Type": contentType], body: .file(file, sha256Hex: hash), progress: progress)
        return link
    }

    /// Every image and video in the bucket, page by page (R2 answers up to 1000 keys at a time).
    func list() async throws -> [UploadedItem] {
        var items: [UploadedItem] = []
        var token: String?
        repeat {
            guard let url = config.listEndpoint(continuationToken: token) else { throw R2Failure.badSettings }
            let page = try await R2Listing.parse(send("GET", url))
            items += page.items
            token = page.nextToken
        } while token != nil
        return items
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

    private enum Body {
        case data(Data)
        case file(URL, sha256Hex: String)
    }

    private func send(_ method: String, _ url: URL, headers: [String: String] = [:], body: Body = .data(Data()),
                      progress: (@Sendable (Double) -> Void)? = nil) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = method
        let signed: SigV4Signer.Request
        switch body {
        case .data(let data):
            signed = .init(method: method, url: url, headers: headers, payload: data)
        case .file(_, let hash):
            signed = .init(method: method, url: url, headers: headers, payloadHash: hash)
            request.timeoutInterval = 600   // a long recording on a slow line
        }
        for (name, value) in signer.headers(for: signed) {
            request.setValue(value, forHTTPHeaderField: name)
        }
        let started = ContinuousClock.now
        let data: Data, response: URLResponse
        let delegate = progress.map(UploadProgressDelegate.init)
        let bytes: Int
        do {
            switch body {
            case .data(let payload):
                bytes = payload.count
                if let delegate {
                    (data, response) = try await URLSession.shared.upload(for: request, from: payload, delegate: delegate)
                } else {
                    request.httpBody = payload
                    (data, response) = try await URLSession.shared.data(for: request)
                }
            case .file(let file, _):
                bytes = (try? FileManager.default.attributesOfItem(atPath: file.path(percentEncoded: false))[.size] as? Int) ?? 0
                (data, response) = try await URLSession.shared.upload(for: request, fromFile: file, delegate: delegate)
            }
        } catch let error as URLError {
            DiagnosticLog.write("r2 \(method) \(url.lastPathComponent) failed: \(error.code.rawValue) \(error.localizedDescription)")
            throw Self.failure(for: error, host: url.host() ?? "")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        DiagnosticLog.write("r2 \(method) \(url.lastPathComponent): HTTP \(status), \(bytes) bytes, "
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

    /// The SHA-256 of a file as lower-case hex, read a megabyte at a time.
    nonisolated static func sha256Hex(ofFile url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func failure(for error: URLError, host: String) -> R2Failure {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .internationalRoamingOff, .dataNotAllowed: .offline
        case .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost, .timedOut: .unreachable(host)
        default: .server(error.localizedDescription)
        }
    }
}

/// Reports how much of the body has gone up (0…1). URLSession calls it off the main thread.
nonisolated private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    private let onProgress: @Sendable (Double) -> Void

    init(_ onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        onProgress(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
    }
}
