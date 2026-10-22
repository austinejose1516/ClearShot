import Foundation

/// What an uploaded file is, for the Uploads window: the folder says it first, then the extension.
/// Anything else in the bucket (the Connect test file, other tools' files) has no kind and is left alone.
public enum UploadKind: String, Sendable, CaseIterable {
    case image, video

    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp"]
    static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]

    public init?(key: String) {
        guard !key.hasSuffix("/") else { return nil }
        if key.hasPrefix("\(R2Folder.images.rawValue)/") { self = .image; return }
        if key.hasPrefix("\(R2Folder.videos.rawValue)/") { self = .video; return }
        let ext = (key as NSString).pathExtension.lowercased()
        if Self.imageExtensions.contains(ext) { self = .image } else if Self.videoExtensions.contains(ext) { self = .video } else { return nil }
    }
}

/// One file in the bucket, as the listing describes it.
public struct UploadedItem: Equatable, Sendable, Identifiable {
    public let key: String
    public let size: Int
    public let modified: Date
    public let kind: UploadKind

    public init(key: String, size: Int, modified: Date, kind: UploadKind) {
        self.key = key
        self.size = size
        self.modified = modified
        self.kind = kind
    }

    public var id: String { key }
    /// "k3x9p2m7qa.png" for "images/k3x9p2m7qa.png".
    public var name: String { (key as NSString).lastPathComponent }
}

/// The switch at the top of the Uploads window.
public enum UploadsFilter: String, CaseIterable, Sendable {
    case all, images, videos

    public var title: String {
        switch self {
        case .all: "All"
        case .images: "Images"
        case .videos: "Videos"
        }
    }

    public func shows(_ kind: UploadKind) -> Bool {
        switch self {
        case .all: true
        case .images: kind == .image
        case .videos: kind == .video
        }
    }
}

/// The S3 `ListObjectsV2` answer, read into items.
public enum R2Listing {
    public struct Page: Equatable, Sendable {
        public let items: [UploadedItem]
        /// Set when the bucket has more than one page; pass it back to get the next one.
        public let nextToken: String?

        public init(items: [UploadedItem], nextToken: String?) {
            self.items = items
            self.nextToken = nextToken
        }
    }

    public static func parse(_ xml: Data) throws -> Page {
        let reader = ListReader()
        let parser = XMLParser(data: xml)
        parser.delegate = reader
        guard parser.parse(), reader.failed == false else { throw R2Failure.server("bad listing") }
        return Page(items: reader.items, nextToken: reader.nextToken)
    }

    /// The items the filter lets through, newest first.
    public static func shown(_ items: [UploadedItem], filter: UploadsFilter) -> [UploadedItem] {
        items.filter { filter.shows($0.kind) }.sorted { $0.modified > $1.modified }
    }

    static func date(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}

/// Collects Key, LastModified and Size inside each Contents, and the continuation token.
private final class ListReader: NSObject, XMLParserDelegate {
    var items: [UploadedItem] = []
    var nextToken: String?
    var failed = false

    private var path: [String] = []
    private var text = ""
    private var key = "", modified = "", size = ""

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        path.append(name)
        text = ""
        if name == "Contents" { (key, modified, size) = ("", "", "") }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        defer { path.removeLast() }
        let inContents = path.dropLast().last == "Contents"
        switch (name, inContents) {
        case ("Key", true): key = text
        case ("LastModified", true): modified = text
        case ("Size", true): size = text
        case ("NextContinuationToken", false): nextToken = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case ("Contents", _):
            if let kind = UploadKind(key: key), let date = R2Listing.date(modified) {
                items.append(UploadedItem(key: key, size: Int(size) ?? 0, modified: date, kind: kind))
            }
        default: break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: any Error) {
        failed = true
    }
}
