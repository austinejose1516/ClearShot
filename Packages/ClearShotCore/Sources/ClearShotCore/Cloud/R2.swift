import Foundation

/// Where uploads go: a Cloudflare R2 bucket. The secret key is not here; the app keeps it in the Keychain.
public struct R2Config: Equatable, Sendable {
    public static let region = "auto"
    public static let service = "s3"

    public var accountID: String
    public var accessKeyID: String
    public var bucket: String
    public var publicURL: String

    public init(accountID: String = "", accessKeyID: String = "", bucket: String = "", publicURL: String = "") {
        self.accountID = accountID
        self.accessKeyID = accessKeyID
        self.bucket = bucket
        self.publicURL = publicURL
    }

    /// All four fields filled in (the secret is checked separately).
    public var isComplete: Bool {
        ![accountID, accessKeyID, bucket, publicURL].contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// The S3-style address of one object: https://<account>.r2.cloudflarestorage.com/<bucket>/<key>
    public func endpoint(key: String) -> URL? {
        let account = accountID.trimmingCharacters(in: .whitespaces)
        let bucket = bucket.trimmingCharacters(in: .whitespaces)
        guard !account.isEmpty, !bucket.isEmpty else { return nil }
        return URL(string: "https://\(account).r2.cloudflarestorage.com/\(bucket)/\(key)")
    }

    /// The link people open: Public URL + "/" + name. A missing "https://" and a trailing "/" are forgiven.
    public func link(name: String) -> URL? {
        var base = publicURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        if !base.contains("://") { base = "https://" + base }
        guard !base.isEmpty, base != "https://" else { return nil }
        return URL(string: "\(base)/\(name)")
    }
}

/// Top-level folders in the bucket, one per kind of capture, so videos and scrolling shots have their own place.
public enum R2Folder: String, CaseIterable, Sendable {
    case images, videos

    /// "images/k3x9p2m7qa.png"
    public func key(for name: String) -> String { "\(rawValue)/\(name)" }
}

/// Random file names for uploads, like "k3x9p2m7qa.png": short, hard to guess, safe in a URL.
public enum R2Name {
    public static let length = 10
    static let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")

    public static func random(format: ImageFormat) -> String {
        var generator = SystemRandomNumberGenerator()
        return random(format: format, using: &generator)
    }

    public static func random(format: ImageFormat, using generator: inout some RandomNumberGenerator) -> String {
        random(fileExtension: format.fileExtension, using: &generator)
    }

    public static func random(fileExtension: String) -> String {
        var generator = SystemRandomNumberGenerator()
        return random(fileExtension: fileExtension, using: &generator)
    }

    public static func random(fileExtension: String, using generator: inout some RandomNumberGenerator) -> String {
        "\(stem(using: &generator)).\(fileExtension)"
    }

    /// The name without an extension: "k3x9p2m7qa".
    public static func stem() -> String {
        var generator = SystemRandomNumberGenerator()
        return stem(using: &generator)
    }

    public static func stem(using generator: inout some RandomNumberGenerator) -> String {
        String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
    }
}

/// Why an upload failed, in words the user can act on.
public enum R2Failure: LocalizedError, Equatable, Sendable {
    case wrongKeys
    case bucketNotFound
    case offline
    /// The address did not answer: a wrong Account ID looks like this, so does a blocked network.
    case unreachable(String)
    case publicURLNotServing
    case badSettings
    case server(String)

    public var errorDescription: String? {
        switch self {
        case .wrongKeys: "The keys were not accepted. Check the Access Key ID and Secret Access Key."
        case .bucketNotFound: "No bucket with that name in this account."
        case .offline: "No internet connection."
        case .unreachable(let host): "Could not reach \(host). Check the Account ID and your internet connection."
        case .publicURLNotServing: "The upload worked, but the Public URL did not return the file. Check the Public URL, and that public access is on for the bucket."
        case .badSettings: "Fill in Account ID, Access Key ID, Secret Access Key, Bucket and Public URL in Settings → Cloud."
        case .server(let detail): "The server said: \(detail)"
        }
    }
}

public enum R2Response {
    /// The failure for a non-2xx answer. R2 answers with XML like `<Error><Code>NoSuchBucket</Code>…`.
    public static func failure(status: Int, body: Data) -> R2Failure {
        let code = errorCode(in: body)
        switch (status, code) {
        case (_, "InvalidAccessKeyId"), (_, "SignatureDoesNotMatch"), (_, "AccessDenied"), (401, _), (403, _): return .wrongKeys
        case (_, "NoSuchBucket"), (404, _): return .bucketNotFound
        default: return .server(code ?? "HTTP \(status)")
        }
    }

    /// The text between `<Code>` and `</Code>`, if any.
    static func errorCode(in body: Data) -> String? {
        guard let text = String(data: body, encoding: .utf8),
              let start = text.range(of: "<Code>"), let end = text.range(of: "</Code>", range: start.upperBound..<text.endIndex) else {
            return nil
        }
        return String(text[start.upperBound..<end.lowerBound])
    }
}
