import Foundation
import Testing
@testable import ClearShotCore

@Suite struct R2ListingTests {
    /// A `ListObjectsV2` answer with an image and a video, as R2 sends it (path-style, XML).
    private func sample(truncated: Bool, extra: String = "") -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
          <Name>shots</Name>
          <KeyCount>2</KeyCount>
          <MaxKeys>1000</MaxKeys>
          <IsTruncated>\(truncated)</IsTruncated>
          \(truncated ? "<NextContinuationToken>tok123</NextContinuationToken>" : "")
          <Contents>
            <Key>images/aaaaaaaaaa.png</Key>
            <LastModified>2026-10-22T14:03:11.000Z</LastModified>
            <ETag>"abc"</ETag>
            <Size>1234</Size>
            <StorageClass>STANDARD</StorageClass>
          </Contents>
          <Contents>
            <Key>videos/bbbbbbbbbb.mp4</Key>
            <LastModified>2026-10-21T09:00:00.000Z</LastModified>
            <ETag>"def"</ETag>
            <Size>56789</Size>
            <StorageClass>STANDARD</StorageClass>
          </Contents>
          \(extra)
        </ListBucketResult>
        """
    }

    @Test func kindComesFromTheFolderThenTheExtension() {
        #expect(UploadKind(key: "images/k3x9p2m7qa.png") == .image)
        #expect(UploadKind(key: "videos/k3x9p2m7qa.mp4") == .video)
        #expect(UploadKind(key: "old/shot.JPG") == .image)
        #expect(UploadKind(key: "clip.mov") == .video)
        #expect(UploadKind(key: "clearshot-test-abc.txt") == nil)
        #expect(UploadKind(key: "images/") == nil)
    }

    @Test func aPageIsParsedWithNameDateAndSize() throws {
        let page = try R2Listing.parse(Data(sample(truncated: false).utf8))
        #expect(page.nextToken == nil)
        #expect(page.items.map(\.key) == ["images/aaaaaaaaaa.png", "videos/bbbbbbbbbb.mp4"])
        #expect(page.items[0].name == "aaaaaaaaaa.png" && page.items[0].size == 1234 && page.items[0].kind == .image)
        #expect(page.items[1].kind == .video && page.items[1].size == 56789)
        #expect(page.items[0].modified == ISO8601DateFormatter().date(from: "2026-10-22T14:03:11Z"))
    }

    @Test func aTruncatedPageCarriesTheNextToken() throws {
        let page = try R2Listing.parse(Data(sample(truncated: true).utf8))
        #expect(page.nextToken == "tok123")
        #expect(page.items.count == 2)
    }

    @Test func keysWithoutAKindAreSkipped() throws {
        let extra = "<Contents><Key>clearshot-test-x.txt</Key><LastModified>2026-10-22T14:03:11.000Z</LastModified><Size>5</Size></Contents>"
        let page = try R2Listing.parse(Data(sample(truncated: false, extra: extra).utf8))
        #expect(page.items.count == 2)
    }

    @Test func brokenXMLIsAnError() {
        #expect(throws: (any Error).self) { try R2Listing.parse(Data("<ListBucketResult><Contents>".utf8)) }
    }

    @Test func shownItemsFollowTheFilterNewestFirst() {
        let old = UploadedItem(key: "images/a.png", size: 1, modified: Date(timeIntervalSince1970: 100), kind: .image)
        let new = UploadedItem(key: "videos/b.mp4", size: 1, modified: Date(timeIntervalSince1970: 200), kind: .video)
        #expect(R2Listing.shown([old, new], filter: .all).map(\.key) == ["videos/b.mp4", "images/a.png"])
        #expect(R2Listing.shown([old, new], filter: .images).map(\.key) == ["images/a.png"])
        #expect(R2Listing.shown([old, new], filter: .videos).map(\.key) == ["videos/b.mp4"])
        #expect(UploadsFilter.all.title == "All" && UploadsFilter.images.title == "Images" && UploadsFilter.videos.title == "Videos")
    }

    @Test func listEndpointAsksForUpToAThousandKeysAndFollowsTheToken() {
        let config = R2Config(accountID: "abc123", accessKeyID: "k", bucket: "shots", publicURL: "https://pub-abc.r2.dev")
        #expect(config.listEndpoint(continuationToken: nil)?.absoluteString
                == "https://abc123.r2.cloudflarestorage.com/shots?list-type=2&max-keys=1000")
        #expect(config.listEndpoint(continuationToken: "a b")?.absoluteString
                == "https://abc123.r2.cloudflarestorage.com/shots?list-type=2&max-keys=1000&continuation-token=a%20b")
        #expect(config.listEndpoint(continuationToken: "x+y/z=")?.absoluteString
                == "https://abc123.r2.cloudflarestorage.com/shots?list-type=2&max-keys=1000&continuation-token=x%2By%2Fz%3D")
        #expect(R2Config().listEndpoint(continuationToken: nil) == nil)
    }
}
