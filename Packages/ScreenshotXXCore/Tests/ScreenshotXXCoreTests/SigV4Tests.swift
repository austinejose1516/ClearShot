import Foundation
import Testing
@testable import ScreenshotXXCore

/// Checked against the worked examples AWS publishes for Signature Version 4 (same keys and date in all of them).
@Suite struct SigV4Tests {
    private let date = ISO8601DateFormatter().date(from: "2015-08-30T12:36:00Z")!
    private let emptyPayloadHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    private func signer(service: String) -> SigV4Signer {
        SigV4Signer(accessKeyID: "AKIDEXAMPLE", secretAccessKey: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
                    region: "us-east-1", service: service)
    }

    @Test func theIAMListUsersExampleFromTheAWSDocs() {
        let signer = signer(service: "iam")
        let url = URL(string: "https://iam.amazonaws.com/?Action=ListUsers&Version=2010-05-08")!
        let headers = ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8",
                       "Host": "iam.amazonaws.com", "X-Amz-Date": "20150830T123600Z"]
        let canonical = signer.canonicalRequest(method: "GET", url: url, headers: headers, payloadHash: emptyPayloadHash)
        #expect(canonical == """
        GET
        /
        Action=ListUsers&Version=2010-05-08
        content-type:application/x-www-form-urlencoded; charset=utf-8
        host:iam.amazonaws.com
        x-amz-date:20150830T123600Z

        content-type;host;x-amz-date
        e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        """)
        let toSign = signer.stringToSign(date: date, canonicalRequest: canonical)
        #expect(toSign == """
        AWS4-HMAC-SHA256
        20150830T123600Z
        20150830/us-east-1/iam/aws4_request
        f536975d06c0309214f805bb90ccff089219ecd68b2577efef23edd43b7e1a59
        """)
        #expect(signer.signature(of: toSign, date: date) == "5d672d79c15b13162d9279b0855cfba6789a8edb4c82c400e06b5924a6f2b5d7")
    }

    @Test func theGetVanillaCaseFromTheAWSTestSuite() {
        let signer = signer(service: "service")
        let canonical = signer.canonicalRequest(
            method: "GET", url: URL(string: "https://example.amazonaws.com/")!,
            headers: ["host": "example.amazonaws.com", "x-amz-date": "20150830T123600Z"], payloadHash: emptyPayloadHash)
        let signature = signer.signature(of: signer.stringToSign(date: date, canonicalRequest: canonical), date: date)
        #expect(signature == "5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31")
    }

    @Test func requestHeadersCarryTheDateThePayloadHashAndTheAuthorization() {
        let signer = signer(service: "s3")
        let url = URL(string: "https://abc.r2.cloudflarestorage.com/shots/k3x9p2m7qa.png")!
        let request = SigV4Signer.Request(method: "PUT", url: url, headers: ["Content-Type": "image/png"], payload: Data("hello".utf8))
        let headers = signer.headers(for: request, date: date)
        #expect(headers["x-amz-date"] == "20150830T123600Z")
        #expect(headers["x-amz-content-sha256"] == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")   // sha256("hello")
        #expect(headers["content-type"] == "image/png")
        #expect(headers["host"] == nil)   // signed, but URLSession sets it
        let authorization = headers["Authorization"] ?? ""
        #expect(authorization.hasPrefix("AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/s3/aws4_request, "
                                        + "SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date, Signature="))
        // The same signature, computed step by step with host included.
        let signed = ["content-type": "image/png", "host": "abc.r2.cloudflarestorage.com", "x-amz-date": "20150830T123600Z",
                      "x-amz-content-sha256": headers["x-amz-content-sha256"]!]
        let canonical = signer.canonicalRequest(method: "PUT", url: url, headers: signed, payloadHash: signed["x-amz-content-sha256"]!)
        let expected = signer.signature(of: signer.stringToSign(date: date, canonicalRequest: canonical), date: date)
        #expect(authorization.hasSuffix("Signature=\(expected)"))
    }

    @Test func encodingAndHeaderCleanup() {
        #expect(SigV4Signer.uriEncode("a b/c~d") == "a%20b%2Fc~d")
        #expect(SigV4Signer.uriEncode("a b/c", keepingSlashes: true) == "a%20b/c")
        #expect(SigV4Signer.trimmed("  a   b  ") == "a b")
        #expect(SigV4Signer.signedHeaderNames(["X-Amz-Date": "", "host": "", "Authorization": ""]) == "host;x-amz-date")
        #expect(SigV4Signer.timestamp(date) == "20150830T123600Z")
        #expect(SigV4Signer.dateStamp(date) == "20150830")
    }
}
