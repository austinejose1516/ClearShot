import AppKit
import ClearShotCore

/// What the Uploads window shows: the bucket's images and videos, the filter, and their pictures while the
/// window is open. `clear()` lets everything go when it closes; the next open lists again.
@Observable
final class UploadsModel {
    /// How many pictures are fetched at once.
    static let thumbnailsAtOnce = 4

    private let settings: AppSettings
    var items: [UploadedItem] = []
    var filter: UploadsFilter = .all
    var isLoading = false
    /// Why the last listing failed, in words; nil when it worked.
    var problem: String?
    /// Settings → Cloud is not connected, so there is nothing to list.
    var cloudMissing = false
    var thumbnails: [String: CGImage] = [:]
    private var loadTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// The items the filter lets through, newest first.
    var shown: [UploadedItem] { R2Listing.shown(items, filter: filter) }

    /// Lists the bucket, then fetches the pictures a few at a time.
    func load() {
        loadTask?.cancel()
        guard let uploader = R2Uploader.fromSettings(settings) else {
            cloudMissing = true
            items = []
            thumbnails = [:]
            return
        }
        cloudMissing = false
        problem = nil
        isLoading = true
        let link = settings.cloud
        loadTask = Task { [weak self] in
            do {
                let items = try await uploader.list()
                guard !Task.isCancelled, let self else { return }
                self.items = items
                self.thumbnails = [:]
                self.isLoading = false
                DiagnosticLog.write("uploads listed: \(items.count) files")
                await self.loadThumbnails(for: items, config: link)
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.isLoading = false
                self.problem = error.localizedDescription
                DiagnosticLog.write("uploads listing failed: \(error.localizedDescription)")
            }
        }
    }

    /// Lets the pictures go (the window closed). The next `load()` lists again.
    func clear() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
        items = []
        thumbnails = [:]
    }

    func copyLink(_ item: UploadedItem) {
        guard let link = settings.cloud.link(name: item.key) else { return }
        UploadService.copy(link)
        Toast.show("Link copied")
    }

    func open(_ item: UploadedItem) {
        guard let link = settings.cloud.link(name: item.key) else { return }
        NSWorkspace.shared.open(link)
    }

    /// Removes the file from the bucket, then the card. A failure says so and the card stays.
    func delete(_ item: UploadedItem) async {
        guard let uploader = R2Uploader.fromSettings(settings) else { return }
        do {
            try await uploader.delete(key: item.key)
            items.removeAll { $0.key == item.key }
            thumbnails[item.key] = nil
            DiagnosticLog.write("deleted upload \(item.key)")
        } catch {
            ErrorPresenter.show(title: "Could not delete \(item.name)", message: error.localizedDescription)
        }
    }

    private func loadThumbnails(for items: [UploadedItem], config: R2Config) async {
        await withTaskGroup(of: (String, CGImage?).self) { group in
            var pending = items.makeIterator()
            func addNext() {
                while let item = pending.next() {
                    guard let link = config.link(name: item.key) else { continue }
                    group.addTask { (item.key, await RemoteThumbnail.load(item, from: link)) }
                    return
                }
            }
            for _ in 0..<Self.thumbnailsAtOnce { addNext() }
            for await (key, image) in group {
                guard !Task.isCancelled else { break }
                if let image { thumbnails[key] = image }
                addNext()
            }
        }
    }
}
