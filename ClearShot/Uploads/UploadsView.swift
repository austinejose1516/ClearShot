import ClearShotCore
import SwiftUI

/// The Uploads window: a filter row on top, then a grid of what is in the bucket, newest first. Hover a card
/// for Copy link, Open in browser and Delete.
struct UploadsView: View {
    static let minimumSize = NSSize(width: 640, height: 420)
    static let defaultSize = NSSize(width: 900, height: 600)

    let model: UploadsModel
    let onOpenCloudSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
    }

    private var header: some View {
        @Bindable var model = model
        return HStack(spacing: 12) {
            Picker("Show", selection: $model.filter) {
                ForEach(UploadsFilter.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
            Text(count)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            Button { model.load() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                .disabled(model.isLoading || model.cloudMissing)
                .help("List the bucket again")
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(.bar)
    }

    private var count: String {
        guard !model.cloudMissing, model.problem == nil else { return "" }
        if model.isLoading { return "Listing…" }
        let shown = model.shown.count
        return shown == 1 ? "1 file" : "\(shown) files"
    }

    @ViewBuilder private var content: some View {
        if model.cloudMissing {
            Placeholder(symbol: "icloud.slash", text: "Set up Settings → Cloud first", button: "Open Settings", action: onOpenCloudSettings)
        } else if let problem = model.problem {
            Placeholder(symbol: "exclamationmark.triangle", text: problem, button: "Try Again") { model.load() }
        } else if model.isLoading {
            ProgressView().controlSize(.large)
        } else if model.shown.isEmpty {
            Placeholder(symbol: "photo.on.rectangle.angled", text: emptyText)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)], alignment: .leading, spacing: 20) {
                    ForEach(model.shown) { item in
                        UploadCard(item: item, thumbnail: model.thumbnails[item.key],
                                   onCopy: { model.copyLink(item) },
                                   onOpen: { model.open(item) },
                                   onDelete: { Task { await model.delete(item) } })
                    }
                }
                .padding(16)
            }
        }
    }

    private var emptyText: String {
        switch model.filter {
        case .all: "Nothing uploaded yet"
        case .images: model.items.isEmpty ? "Nothing uploaded yet" : "No images yet"
        case .videos: model.items.isEmpty ? "Nothing uploaded yet" : "No videos yet"
        }
    }
}

/// A symbol, a line of text, and (sometimes) one button, in the middle of the window.
private struct Placeholder: View {
    let symbol: String
    let text: String
    var button: String?
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text(text)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            if let button {
                Button(button, action: action)
            }
        }
        .padding(24)
    }
}

/// One file: the picture, the name, the date and the size. On hover a glass bar with the three actions.
private struct UploadCard: View {
    let item: UploadedItem
    let thumbnail: CGImage?
    let onCopy: () -> Void
    let onOpen: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false
    @State private var asksToDelete = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            picture
            Text(item.name)
                .font(.callout.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
            Text("\(item.modified.formatted(.relative(presentation: .named))) · \(size)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Copy Link", systemImage: "link", action: onCopy)
            Button("Open in Browser", systemImage: "safari", action: onOpen)
            Divider()
            Button("Delete…", systemImage: "trash", role: .destructive) { asksToDelete = true }
        }
        .confirmationDialog("Delete \(item.name)?", isPresented: $asksToDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("It cannot be undone.")
        }
    }

    private var size: String {
        ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .file)
    }

    private var picture: some View {
        Color.clear
            .aspectRatio(16 / 10, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    Image(decorative: thumbnail, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(.quaternary)
                    ProgressView().controlSize(.small)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.1)))
            .overlay(alignment: .topLeading) {
                if item.kind == .video {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .padding(7)
                        .glassEffect(.regular, in: .circle)
                        .padding(8)
                        .help("Video")
                }
            }
            .overlay(alignment: .bottom) {
                if hovering {
                    actions
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.2), value: hovering)
    }

    private var actions: some View {
        HStack(spacing: 2) {
            IconButton(symbol: copied ? "checkmark" : "link", help: "Copy the link") {
                onCopy()
                withAnimation(.snappy(duration: 0.2)) { copied = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    withAnimation(.easeOut(duration: 0.2)) { copied = false }
                }
            }
            .symbolEffect(.bounce, value: copied)
            IconButton(symbol: "safari", help: "Open in the browser", action: onOpen)
            IconButton(symbol: "trash", help: "Delete from the bucket") { asksToDelete = true }
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
    }
}

private struct IconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 26)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
