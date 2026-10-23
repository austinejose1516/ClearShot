import AppKit
import ClearShotCore

/// What the Uploads window shows: the bucket's images and videos, the filter, the selection, and their
/// pictures while the window is open. `clear()` lets everything go when it closes; the next open lists again.
@Observable
final class UploadsModel {
    /// How many pictures are fetched at once.
    static let thumbnailsAtOnce = 4

    private let settings: AppSettings
    var items: [UploadedItem] = []
    var filter: UploadsFilter = .all {
        didSet { selection.keep(in: shownKeys) }
    }
    var isLoading = false
    /// Why the last listing failed, in words; nil when it worked.
    var problem: String?
    /// Settings → Cloud is not connected, so there is nothing to list.
    var cloudMissing = false
    var thumbnails: [String: CGImage] = [:]
    var selection = UploadSelection()
    /// How many cards the grid fits side by side now, for the up and down arrows.
    var columns = 1
    /// What a Delete is about to remove, while the question is up; nil otherwise.
    var pendingDelete: [UploadedItem]?
    var isDeleting = false
    private var loadTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// The items the filter lets through, newest first.
    var shown: [UploadedItem] { R2Listing.shown(items, filter: filter) }

    private var shownKeys: [String] { shown.map(\.key) }

    /// The selected items, in the grid's order.
    var selectedItems: [UploadedItem] { shown.filter { selection.keys.contains($0.key) } }

    /// The one selected item, when exactly one is: what Copy Link and Open work on.
    var onlySelected: UploadedItem? {
        guard let key = selection.only else { return nil }
        return items.first { $0.key == key }
    }

    // MARK: - Listing

    /// Lists the bucket, then fetches the pictures a few at a time.
    func load() {
        loadTask?.cancel()
        guard let uploader = R2Uploader.fromSettings(settings) else {
            cloudMissing = true
            items = []
            thumbnails = [:]
            selection.clear()
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
                self.selection.clear()
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
        selection.clear()
        pendingDelete = nil
    }

    // MARK: - Selecting

    func click(_ item: UploadedItem, modifiers: UploadSelection.Modifiers) {
        selection.click(item.key, in: shownKeys, modifiers: modifiers)
    }

    /// A key press, as the window reads it.
    func perform(_ command: UploadsCommand) {
        switch command {
        case .selectAll: selection.selectAll(shownKeys)
        case .clear: selection.clear()
        case .move(let direction): selection.move(direction, in: shownKeys, columns: columns)
        case .copyLink: onlySelected.map(copyLink)
        case .open: onlySelected.map(open)
        case .delete: askToDelete(selectedItems)
        }
    }

    // MARK: - Actions

    func copyLink(_ item: UploadedItem) {
        guard let link = settings.cloud.link(name: item.key) else { return }
        UploadService.copy(link)
        Toast.show("Link copied")
    }

    func open(_ item: UploadedItem) {
        guard let link = settings.cloud.link(name: item.key) else { return }
        NSWorkspace.shared.open(link)
    }

    /// Puts the question up; the view shows it and calls `deletePending()` on Delete.
    func askToDelete(_ targets: [UploadedItem]) {
        guard !targets.isEmpty, !isDeleting else { return }
        pendingDelete = targets
    }

    func deletePending() {
        guard let targets = pendingDelete else { return }
        pendingDelete = nil
        Task { await delete(targets) }
    }

    /// Removes the files from the bucket one after the other, and each card as its file goes. A failure stops
    /// there and says which file; the ones after it stay.
    func delete(_ targets: [UploadedItem]) async {
        guard let uploader = R2Uploader.fromSettings(settings) else { return }
        isDeleting = true
        defer { isDeleting = false }
        var deleted = 0
        for item in targets {
            do {
                try await uploader.delete(key: item.key)
                items.removeAll { $0.key == item.key }
                thumbnails[item.key] = nil
                selection.keep(in: shownKeys)
                deleted += 1
                DiagnosticLog.write("deleted upload \(item.key)")
            } catch {
                let rest = targets.count - deleted - 1
                ErrorPresenter.show(title: "Could not delete \(item.name)",
                                    message: rest > 0 ? "\(error.localizedDescription)\n\nThe \(rest) after it were not deleted." : error.localizedDescription)
                return
            }
        }
        if deleted > 1 { Toast.show("\(deleted) files deleted", symbol: "trash") }
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
