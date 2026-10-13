import ScreenshotXXCore
import SwiftUI

struct EditorToolbar: View {
    let document: EditorDocument
    let state: EditorState
    let onCopy: () -> Void
    let onSave: () -> Void
    let onExportAs: () -> Void

    var body: some View {
        @Bindable var state = state
        HStack(spacing: 10) {
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
            HStack(spacing: 4) {
                ForEach(RGBAColor.presets, id: \.self) { preset in
                    Button {
                        state.strokeColor = preset
                        state.applyStyle(to: document)
                    } label: {
                        Circle()
                            .fill(Color(preset))
                            .stroke(.primary.opacity(state.strokeColor == preset ? 0.9 : 0.25),
                                    lineWidth: state.strokeColor == preset ? 2 : 1)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            Picker("Width", selection: $state.strokeWidth) {
                ForEach(EditorState.widths, id: \.self) { Text("\(Int($0)) px").tag($0) }
            }
            .labelsHidden()
            .frame(width: 80)
            .onChange(of: state.strokeWidth) { state.applyStyle(to: document) }
            Toggle("Fill", isOn: $state.fills)
                .toggleStyle(.checkbox)
                .disabled(!state.tool.usesFill && document.selection.isEmpty)
                .onChange(of: state.fills) { state.applyStyle(to: document) }
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
            .frame(width: 80)
            Spacer(minLength: 16)
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 4)
            }
            .fixedSize()
            .help("Copy to clipboard (⌘C)")
            Button(action: onSave) {
                Label("Save", systemImage: "square.and.arrow.down")
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.borderedProminent)
            .fixedSize()
            .help("Save into the screenshot file (⌘S)")
            Menu {
                Button("Export As…", action: onExportAs)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("More")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
