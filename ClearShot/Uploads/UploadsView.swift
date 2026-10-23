import ClearShotCore
import SwiftUI

/// The Uploads window: a header with the filter and the actions for the selection, then a grid of what is in
/// the bucket, newest first. Cards are selected like the Finder's (click, ⌘-click, ⇧-click, ⌘A, the arrows);
/// Copy Link and Open in Browser work on one card, Delete on all selected; a drag over empty space draws a box
/// that selects what it touches. Hover a card for the same three actions on that card alone.
struct UploadsView: View {
    static let minimumSize = NSSize(width: 640, height: 420)
    static let defaultSize = NSSize(width: 900, height: 600)
    /// The grid's columns: cards at least this wide, this far apart, inside this much padding.
    static let cardMinimum: CGFloat = 200
    static let gridSpacing: CGFloat = 16
    static let gridPadding: CGFloat = 16

    let model: UploadsModel
    let onOpenCloudSettings: () -> Void

    /// Where each shown card is in the grid, for the drag box.
    @State private var frames: [String: CGRect] = [:]
    /// The drag box while it is being drawn: where it began, what was selected then (⌘ keeps that), and where
    /// the mouse is in the window, for scrolling on while it is held past an edge.
    @State private var box: CGRect?
    @State private var boxStart: CGPoint?
    @State private var boxBase: Set<String>?
    @State private var mouseInViewport: CGPoint?
    @State private var autoscroll: Task<Void, Never>?
    @State private var position = ScrollPosition()
    @State private var viewport = Viewport()

    /// What is seen of the grid: how far it is scrolled, how tall the window's part is, how tall the whole is.
    private struct Viewport: Equatable {
        var offset: CGFloat = 0
        var height: CGFloat = 0
        var contentHeight: CGFloat = 0
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
        .confirmationDialog(deleteQuestion, isPresented: asksToDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { model.deletePending() }
        } message: {
            Text("It cannot be undone.")
        }
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
            Divider().frame(height: 20)
            HeaderButton(title: "Copy Link", symbol: "link", tint: nil, enabled: model.onlySelected != nil,
                         help: "Copy the link of the selected file (⌘C)") { model.onlySelected.map(model.copyLink) }
            HeaderButton(title: "Open in Browser", symbol: "safari", tint: nil, enabled: model.onlySelected != nil,
                         help: "Open the selected file in the browser (Return)") { model.onlySelected.map(model.open) }
            HeaderButton(title: "Delete", symbol: "trash", tint: .red, enabled: !model.selection.isEmpty && !model.isDeleting,
                         help: "Delete the selected files from the bucket (⌫)") { model.askToDelete(model.selectedItems) }
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
        let selected = model.selection.keys.count
        if selected > 0 { return "\(selected) of \(shown) selected" }
        return shown == 1 ? "1 file" : "\(shown) files"
    }

    private var deleteQuestion: String {
        guard let targets = model.pendingDelete else { return "" }
        return targets.count == 1 ? "Delete \(targets[0].name)?" : "Delete \(targets.count) files?"
    }

    private var asksToDelete: Binding<Bool> {
        Binding(get: { model.pendingDelete != nil }, set: { if !$0 { model.pendingDelete = nil } })
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
            grid
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.cardMinimum, maximum: 280), spacing: Self.gridSpacing)],
                      alignment: .leading, spacing: 20) {
                ForEach(model.shown) { item in
                    UploadCard(item: item, thumbnail: model.thumbnails[item.key],
                               isSelected: model.selection.keys.contains(item.key),
                               targets: model.selection.keys.contains(item.key) ? model.selectedItems : [item],
                               onClick: { model.click(item, modifiers: Self.clickModifiers) },
                               onCopy: { model.copyLink(item) },
                               onOpen: { model.open(item) },
                               onDelete: { model.askToDelete($0) })
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("grid")) } action: { frames[item.key] = $0 }
                }
            }
            .padding(Self.gridPadding)
            // The space between and below the cards, down to the bottom of the window: a click there clears the
            // selection, a drag draws the box.
            .frame(maxWidth: .infinity, minHeight: viewport.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .coordinateSpace(.named("grid"))
            .onTapGesture { model.selection.clear() }
            .simultaneousGesture(boxGesture)
            .overlay(alignment: .topLeading) {
                if let box {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.tint.opacity(0.15))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.tint.opacity(0.7), lineWidth: 1))
                        .frame(width: box.width, height: box.height)
                        .offset(x: box.minX, y: box.minY)
                        .allowsHitTesting(false)
                }
            }
        }
        .scrollPosition($position)
        .onScrollGeometryChange(for: Viewport.self) { geometry in
            Viewport(offset: geometry.contentOffset.y, height: geometry.containerSize.height, contentHeight: geometry.contentSize.height)
        } action: { _, seen in
            viewport = seen
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            model.columns = UploadSelection.columns(forWidth: width - 2 * Self.gridPadding,
                                                    minimum: Self.cardMinimum, spacing: Self.gridSpacing)
        }
    }

    /// A drag over the grid selects what the box touches; with ⌘ held it adds to what was selected. Held past
    /// the top or bottom edge, the grid scrolls on and the box grows with it.
    private var boxGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("grid"))
            .onChanged { value in
                if boxBase == nil {
                    boxBase = Self.clickModifiers.contains(.command) ? model.selection.keys : []
                    boxStart = value.startLocation
                    startAutoscroll()
                }
                mouseInViewport = CGPoint(x: value.location.x, y: value.location.y - viewport.offset)
                extendBox(to: value.location)
            }
            .onEnded { _ in endBox() }
    }

    private func extendBox(to point: CGPoint) {
        guard let boxStart, let boxBase else { return }
        let rect = SelectionGeometry.normalizedRect(from: boxStart, to: point)
        box = rect
        model.selection.box(UploadSelection.keys(in: rect, frames: frames), onto: boxBase)
    }

    /// While the box is held within `edge` of the top or bottom, scrolls a step every frame.
    private func startAutoscroll() {
        autoscroll?.cancel()
        autoscroll = Task { @MainActor in
            let edge: CGFloat = 28
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard let mouse = mouseInViewport else { continue }
                let step: CGFloat = mouse.y < edge ? -8 : (mouse.y > viewport.height - edge ? 8 : 0)
                let target = min(max(viewport.offset + step, 0), max(viewport.contentHeight - viewport.height, 0))
                guard step != 0, target != viewport.offset else { continue }
                position.scrollTo(y: target)
                extendBox(to: CGPoint(x: mouse.x, y: mouse.y + target))
            }
        }
    }

    private func endBox() {
        autoscroll?.cancel()
        autoscroll = nil
        box = nil
        boxStart = nil
        boxBase = nil
        mouseInViewport = nil
    }

    /// ⌘ and ⇧ as they are held for the click being handled.
    private static var clickModifiers: UploadSelection.Modifiers {
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        var modifiers = UploadSelection.Modifiers()
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }

    private var emptyText: String {
        switch model.filter {
        case .all: "Nothing uploaded yet"
        case .images: model.items.isEmpty ? "Nothing uploaded yet" : "No images yet"
        case .videos: model.items.isEmpty ? "Nothing uploaded yet" : "No videos yet"
        }
    }
}

/// A header action: solid in its colour (the accent, or red for Delete) while it can be used, faded when it
/// cannot, so the state is plain to see.
private struct HeaderButton: View {
    let title: String
    let symbol: String
    let tint: Color?
    let enabled: Bool
    let help: String
    let action: () -> Void

    var body: some View {
        Group {
            if enabled {
                Button(action: action) { Label(title, systemImage: symbol) }
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
            } else {
                Button(action: action) { Label(title, systemImage: symbol) }
                    .buttonStyle(.bordered)
                    .disabled(true)
            }
        }
        .help(help)
        .animation(.snappy(duration: 0.15), value: enabled)
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

/// One file: the picture, the name, the date and the size. A click selects it (the picture gets an accent
/// ring, the card an accent wash), a double-click opens it. On hover a glass bar with the three actions for
/// this card alone. The right-click menu acts on `targets`: the whole selection when this card is in it.
private struct UploadCard: View {
    let item: UploadedItem
    let thumbnail: CGImage?
    let isSelected: Bool
    let targets: [UploadedItem]
    let onClick: () -> Void
    let onCopy: () -> Void
    let onOpen: () -> Void
    let onDelete: ([UploadedItem]) -> Void

    @State private var hovering = false
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
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.tint.opacity(0.14))
                    .padding(-6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onClick)
        .simultaneousGesture(TapGesture(count: 2).onEnded(onOpen))
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Copy Link", systemImage: "link", action: onCopy).disabled(targets.count != 1)
            Button("Open in Browser", systemImage: "safari", action: onOpen).disabled(targets.count != 1)
            Divider()
            Button(targets.count == 1 ? "Delete…" : "Delete \(targets.count) Files…", systemImage: "trash", role: .destructive) {
                onDelete(targets)
            }
        }
        .animation(.snappy(duration: 0.15), value: isSelected)
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
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary.opacity(0.1)),
                                                                     lineWidth: isSelected ? 2.5 : 1))
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
            IconButton(symbol: "trash", help: "Delete from the bucket") { onDelete([item]) }
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
