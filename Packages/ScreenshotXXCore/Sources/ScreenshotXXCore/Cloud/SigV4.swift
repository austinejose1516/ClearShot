import CryptoKit
import Foundation

/// AWS Signature Version 4: proves to the server that a request was made with your keys, without sending the
/// secret. Cloudflare R2 speaks it too. Pure: no networking, so every step is testable against AWS's examples.
public struct SigV4Signer: Sendable {
    public let accessKeyID: String
    public let secretAccessKey: String
    public let region: String
    public let service: String

    public init(accessKeyID: String, secretAccessKey: String, region: String, service: String) {
        self.accessKeyID = accessKeyID
        self.secretAccessKey = secretAccessKey
        self.region = region
        self.service = service
    }

    /// A request as the signature sees it.
    public struct Request: Sendable {
        public var method: String
        public var url: URL
        /// Extra headers to send and sign (e.g. content-type). Host, the date and the payload hash are added.
        public var headers: [String: String]
        public var payload: Data

        public init(method: String, url: URL, headers: [String: String] = [:], payload: Data = Data()) {
            self.method = method
            self.url = url
            self.headers = headers
            self.payload = payload
        }
    }

    /// The headers to put on the request: the given ones plus x-amz-date, x-amz-content-sha256 and
    /// Authorization. Host is signed but not returned; URLSession sets it itself.
    public func headers(for request: Request, date: Date = .now) -> [String: String] {
        var headers = request.headers.reduce(into: [String: String]()) { $0[$1.key.lowercased()] = $1.value }
        headers["host"] = request.url.host() ?? ""
        headers["x-amz-date"] = Self.timestamp(date)
        headers["x-amz-content-sha256"] = Self.hex(SHA256.hash(data: request.payload))
        let canonical = canonicalRequest(method: request.method, url: request.url, headers: headers,
                                         payloadHash: headers["x-amz-content-sha256"]!)
        let signature = signature(of: stringToSign(date: date, canonicalRequest: canonical), date: date)
        headers["Authorization"] = "AWS4-HMAC-SHA256 Credential=\(accessKeyID)/\(scope(date)), "
            + "SignedHeaders=\(Self.signedHeaderNames(headers)), Signature=\(signature)"
        headers.removeValue(forKey: "host")
        return headers
    }

    // MARK: - The steps (public so tests can check each against AWS's published values)

    /// Method, path, sorted query, sorted lower-cased headers, the signed header names, the payload hash.
    public func canonicalRequest(method: String, url: URL, headers: [String: String], payloadHash: String) -> String {
        let path = url.path(percentEncoded: false)
        let query = (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .map { (Self.uriEncode($0.name), Self.uriEncode($0.value ?? "")) }
            .sorted { $0 < $1 }
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "&")
        let canonicalHeaders = headers
            .map { (name: $0.key.lowercased(), value: Self.trimmed($0.value)) }
            .sorted { $0.name < $1.name }
            .map { "\($0.name):\($0.value)\n" }
            .joined()
        return [method.uppercased(), Self.uriEncode(path.isEmpty ? "/" : path, keepingSlashes: true), query,
                canonicalHeaders, Self.signedHeaderNames(headers), payloadHash].joined(separator: "\n")
    }

    public func stringToSign(date: Date, canonicalRequest: String) -> String {
        ["AWS4-HMAC-SHA256", Self.timestamp(date), scope(date),
         Self.hex(SHA256.hash(data: Data(canonicalRequest.utf8)))].joined(separator: "\n")
    }

    /// The signing key is derived step by step from the secret: date, region, service, then "aws4_request".
    public func signature(of stringToSign: String, date: Date) -> String {
        var key = SymmetricKey(data: Data("AWS4\(secretAccessKey)".utf8))
        for part in [Self.dateStamp(date), region, service, "aws4_request"] {
            key = SymmetricKey(data: HMAC<SHA256>.authenticationCode(for: Data(part.utf8), using: key))
        }
        return Self.hex(HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: key))
    }

    /// "20150830/us-east-1/iam/aws4_request"
    public func scope(_ date: Date) -> String {
        "\(Self.dateStamp(date))/\(region)/\(service)/aws4_request"
    }

    // MARK: - Helpers

    /// "20150830T123600Z"
    public static func timestamp(_ date: Date) -> String {
        format(date, "yyyyMMdd'T'HHmmss'Z'")
    }

    /// "20150830"
    public static func dateStamp(_ date: Date) -> String {
        format(date, "yyyyMMdd")
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    /// Lower-cased header names, sorted, joined with ";".
    static func signedHeaderNames(_ headers: [String: String]) -> String {
        headers.keys.map { $0.lowercased() }.filter { $0 != "authorization" }.sorted().joined(separator: ";")
    }

    /// Header values lose outer spaces, and runs of spaces inside become one.
    static func trimmed(_ value: String) -> String {
        value.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }

    /// RFC 3986 encoding: only letters, digits and "-_.~" stay (and "/" in a path).
    static func uriEncode(_ text: String, keepingSlashes: Bool = false) -> String {
        var allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")
        if keepingSlashes { allowed.insert("/") }
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    static func hex(_ digest: some Sequence<UInt8>) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
