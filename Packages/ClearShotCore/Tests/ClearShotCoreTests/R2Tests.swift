import Foundation
import Testing
@testable import ClearShotCore

@Suite struct R2Tests {
    @Test func endpointAndLinkComeFromTheSettings() {
        let config = R2Config(accountID: "abc123", accessKeyID: "k", bucket: "shots", publicURL: "https://pub-abc.r2.dev/")
        #expect(config.endpoint(key: "k3x9p2m7qa.png")?.absoluteString == "https://abc123.r2.cloudflarestorage.com/shots/k3x9p2m7qa.png")
        #expect(config.link(name: "k3x9p2m7qa.png")?.absoluteString == "https://pub-abc.r2.dev/k3x9p2m7qa.png")
        #expect(R2Config(publicURL: "shots.example.com").link(name: "a.png")?.absoluteString == "https://shots.example.com/a.png")
        #expect(R2Config().link(name: "a.png") == nil)
        #expect(R2Config().endpoint(key: "a.png") == nil)
    }

    @Test func uploadsSitInAFolderPerKind() {
        let config = R2Config(accountID: "abc123", accessKeyID: "k", bucket: "shots", publicURL: "https://pub-abc.r2.dev")
        let key = R2Folder.images.key(for: "k3x9p2m7qa.png")
        #expect(key == "images/k3x9p2m7qa.png")
        #expect(R2Folder.videos.key(for: "a.mp4") == "videos/a.mp4")
        #expect(config.endpoint(key: key)?.absoluteString == "https://abc123.r2.cloudflarestorage.com/shots/images/k3x9p2m7qa.png")
        #expect(config.link(name: key)?.absoluteString == "https://pub-abc.r2.dev/images/k3x9p2m7qa.png")
    }

    @Test func completeMeansAllFourFieldsAreFilledIn() {
        #expect(R2Config().isComplete == false)
        #expect(R2Config(accountID: "a", accessKeyID: "k", bucket: "b", publicURL: " ").isComplete == false)
        #expect(R2Config(accountID: "a", accessKeyID: "k", bucket: "b", publicURL: "https://x").isComplete)
    }

    @Test func randomNamesAreTenLowercaseLettersOrDigitsPlusTheExtension() {
        var generator = SystemRandomNumberGenerator()
        let png = R2Name.random(format: .png, using: &generator)
        let jpg = R2Name.random(format: .jpeg)
        #expect(png.hasSuffix(".png") && jpg.hasSuffix(".jpg"))
        let stem = png.dropLast(4)
        #expect(stem.count == 10)
        #expect(stem.allSatisfy { ($0.isLetter && $0.isLowercase) || $0.isNumber })
        #expect(R2Name.random(format: .png) != R2Name.random(format: .png))
        #expect(R2Name.stem().count == 10 && !R2Name.stem().contains("."))
        let mp4 = R2Name.random(fileExtension: "mp4", using: &generator)
        #expect(mp4.hasSuffix(".mp4") && mp4.count == 14)
    }

    @Test func serverAnswersBecomePlainFailures() {
        func xml(_ code: String) -> Data {
            Data("<?xml version=\"1.0\"?><Error><Code>\(code)</Code><Message>x</Message></Error>".utf8)
        }
        #expect(R2Response.failure(status: 403, body: xml("SignatureDoesNotMatch")) == .wrongKeys)
        #expect(R2Response.failure(status: 400, body: xml("InvalidAccessKeyId")) == .wrongKeys)
        #expect(R2Response.failure(status: 403, body: Data()) == .wrongKeys)
        #expect(R2Response.failure(status: 404, body: xml("NoSuchBucket")) == .bucketNotFound)
        #expect(R2Response.failure(status: 500, body: xml("InternalError")) == .server("InternalError"))
        #expect(R2Response.failure(status: 502, body: Data()) == .server("HTTP 502"))
        #expect(R2Failure.wrongKeys.errorDescription?.contains("Access Key ID") == true)
        #expect(R2Failure.unreachable("abc.r2.cloudflarestorage.com").errorDescription?.contains("Account ID") == true)
    }
}
