import ScreenshotXXCore
import SwiftUI

/// Two rows: tools and file actions on top, style options for the current tool or selection below.
struct EditorToolbar: View {
    let document: EditorDocument
    let state: EditorState
    let onCopy: () -> Void
    let onSave: () -> Void
    let onSaveAs: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            Divider()
            optionsRow
        }
    }

    // MARK: - Row 1

    private var mainRow: some View {
        @Bindable var state = state
        return HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(EditorTool.allCases) { tool in
                    Button {
                        state.tool = tool
                    } label: {
                        Image(systemName: tool.symbol)
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 30, height: 26)
                    }
                    .buttonStyle(.borderless)
                    .background(state.tool == tool ? Color.accentColor.opacity(0.22) : .clear,
                                in: RoundedRectangle(cornerRadius: 6))
                    .help(tool.title)
                }
            }
            Divider().frame(height: 20)
            Button { document.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!document.canUndo).help("Undo (⌘Z)")
            Button { document.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!document.canRedo).help("Redo (⇧⌘Z)")
            Button { document.remove(ids: document.selection) } label: { Image(systemName: "trash") }
                .disabled(document.selection.isEmpty).help("Delete")
            Divider().frame(height: 20)
            Picker("Zoom", selection: Binding(
                get: { state.zoomIsFit ? 0 : state.zoom },
                set: { value in
                    if value == 0 { state.zoomIsFit = true } else { state.zoomIsFit = false; state.zoom = value }
                })) {
                Text("Fit").tag(CGFloat(0))
                Text("50 %").tag(CGFloat(0.5))
                Text("100 %").tag(CGFloat(1))
                Text("200 %").tag(CGFloat(2))
            }
            .labelsHidden()
            .fixedSize()
            Spacer(minLength: 16)
            Toggle(isOn: $state.showsFramePanel) {
                Label("Frame", systemImage: "sidebar.right").labelStyle(.titleAndIcon)
            }
            .toggleStyle(.button)
            .fixedSize()
            .help("Show or hide the frame panel: background, padding, corners, shadow")
            .onChange(of: state.showsFramePanel) { _, shown in
                if shown, document.frame == FrameStyle() {
                    document.setFrame(.starter)
                    document.commit()
                }
            }
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 4)
            }
            .fixedSize()
            .help("Copy the result to the clipboard and close (⌘C)")
            Menu {
                Button("Save As…", action: onSaveAs)
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 4)
            } primaryAction: {
                onSave()
            }
            .buttonStyle(.borderedProminent)
            .fixedSize()
            .help("Save into the screenshot file (⌘S). Arrow: Save As…")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Row 2

    private var optionsRow: some View {
        @Bindable var state = state
        return HStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(RGBAColor.presets, id: \.self) { preset in
                    Button {
                        state.strokeColor = preset
                        state.applyStyle(to: document)
                    } label: {
                        Circle()
                            .fill(Color(preset))
                            .stroke(.primary.opacity(state.strokeColor.sameColor(as: preset) ? 0.9 : 0.25),
                                    lineWidth: state.strokeColor.sameColor(as: preset) ? 2 : 1)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            Divider().frame(height: 18)
            Picker("Width", selection: $state.strokeWidth) {
                ForEach(EditorState.widths, id: \.self) { Text("\(Int($0)) px").tag($0) }
            }
            .fixedSize()
            .onChange(of: state.strokeWidth) { state.applyStyle(to: document) }
            Picker("Opacity", selection: $state.opacity) {
                ForEach(EditorState.opacities, id: \.self) { Text("\(Int($0 * 100)) %").tag($0) }
            }
            .fixedSize()
            .onChange(of: state.opacity) { state.applyStyle(to: document) }
            if state.tool.usesFill || selectionHasShape {
                Toggle("Fill", isOn: $state.fills)
                    .toggleStyle(.checkbox)
                    .fixedSize()
                    .onChange(of: state.fills) { state.applyStyle(to: document) }
            }
            if selectionHasArrowable {
                Toggle("Arrowhead", isOn: Binding(
                    get: { selectedArrowhead },
                    set: { state.applyArrowhead($0, to: document) }))
                    .toggleStyle(.checkbox)
                    .fixedSize()
            }
            if state.tool == .blur || selectionHas(.blur) {
                Picker("Mode", selection: $state.blurMode) {
                    Text("Pixelate").tag(BlurMode.pixelate)
                    Text("Blur").tag(BlurMode.blur)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .onChange(of: state.blurMode) { state.applyStyle(to: document) }
            }
            if state.tool == .text || selectionHasText || state.tool == .bubble || selectionHas(.bubble) {
                Divider().frame(height: 18)
                Picker("Size", selection: $state.fontSize) {
                    ForEach(EditorState.fontSizes, id: \.self) { Text("\(Int($0))").tag($0) }
                }
                .fixedSize()
                .onChange(of: state.fontSize) { state.applyStyle(to: document) }
                if state.tool == .text || selectionHasText {
                    Toggle("Bold", isOn: $state.bold)
                        .toggleStyle(.checkbox)
                        .fixedSize()
                        .onChange(of: state.bold) { state.applyStyle(to: document) }
                    Toggle("Boxed", isOn: $state.boxed)
                        .toggleStyle(.checkbox)
                        .fixedSize()
                        .onChange(of: state.boxed) { state.applyStyle(to: document) }
                }
            }
            Spacer(minLength: 0)
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
    }

    private var hint: String {
        switch state.tool {
        case .select: "Click to select · drag to move · drag a handle to resize · Delete removes"
        case .line, .arrow: "Drag to draw"
        case .curve: "Drag to draw, then drag the middle handle to bend"
        case .pen: "Drag to draw freehand"
        case .rect, .ellipse: "Drag to draw · Fill for a solid shape"
        case .text: "Click to place text · Enter or Esc to finish · click again to edit"
        case .bubble: "Drag to draw the bubble, type, then drag its tail"
        case .step: "Click to place the next number"
        case .blur: "Drag over the part to hide"
        case .crop: "Drag the part to keep · Enter crops · Esc cancels"
        }
    }

    private var selected: [Annotation] {
        document.annotations.filter { document.selection.contains($0.id) }
    }

    private var selectionHasShape: Bool {
        selected.contains { if case .rect = $0.kind { true } else if case .ellipse = $0.kind { true } else { false } }
    }

    private var selectionHasText: Bool {
        selected.contains { if case .text = $0.kind { true } else { false } }
    }

    private enum KindFilter { case blur, bubble }

    private func selectionHas(_ filter: KindFilter) -> Bool {
        selected.contains {
            switch ($0.kind, filter) {
            case (.blur, .blur), (.speechBubble, .bubble): true
            default: false
            }
        }
    }

    private var selectionHasArrowable: Bool {
        selected.contains { if case .line = $0.kind { true } else if case .curve = $0.kind { true } else { false } }
    }

    private var selectedArrowhead: Bool {
        selected.contains {
            switch $0.kind {
            case .line(_, _, _, let end), .curve(_, _, _, let end): end
            default: false
            }
        }
    }
}
