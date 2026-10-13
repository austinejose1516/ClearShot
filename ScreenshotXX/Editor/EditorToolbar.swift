import ScreenshotXXCore
import SwiftUI

/// Two rows: tools and file actions on top; below, only the settings that apply to the tool or the selection.
struct EditorToolbar: View {
    let session: EditorSession
    let viewState: EditorViewState
    let onCommand: (EditorCommand) -> Void

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            Divider()
            optionsRow
        }
    }

    // MARK: - Row 1

    private var mainRow: some View {
        @Bindable var session = session
        @Bindable var viewState = viewState
        return HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(EditorTool.allCases) { tool in
                    Button {
                        session.tool = tool
                    } label: {
                        Image(systemName: tool.symbol)
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 30, height: 26)
                    }
                    .buttonStyle(.borderless)
                    .background(session.tool == tool ? Color.accentColor.opacity(0.22) : .clear,
                                in: RoundedRectangle(cornerRadius: 6))
                    .help(tool.title)
                }
            }
            Divider().frame(height: 20)
            Button { onCommand(.undo) } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!session.document.canUndo).help("Undo (⌘Z)")
            Button { onCommand(.redo) } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!session.document.canRedo).help("Redo (⇧⌘Z)")
            Button { onCommand(.delete) } label: { Image(systemName: "trash") }
                .disabled(session.document.selection.isEmpty).help("Delete")
            Divider().frame(height: 20)
            Picker("Zoom", selection: Binding(
                get: { viewState.zoomIsFit ? 0 : viewState.zoom },
                set: { value in
                    if value == 0 { viewState.zoomIsFit = true } else { viewState.zoomIsFit = false; viewState.zoom = value }
                })) {
                Text("Fit").tag(CGFloat(0))
                Text("50 %").tag(CGFloat(0.5))
                Text("100 %").tag(CGFloat(1))
                Text("200 %").tag(CGFloat(2))
            }
            .labelsHidden()
            .fixedSize()
            Spacer(minLength: 16)
            Toggle(isOn: $viewState.showsFramePanel) {
                Label("Frame", systemImage: "sidebar.right").labelStyle(.titleAndIcon)
            }
            .toggleStyle(.button)
            .fixedSize()
            .help("Show or hide the frame panel: background, padding, corners, shadow")
            .onChange(of: viewState.showsFramePanel) { _, shown in
                if shown, session.document.frame == FrameStyle() {
                    session.document.setFrame(.starter)
                    session.document.commit()
                }
            }
            Button { onCommand(.copy) } label: {
                Label("Copy", systemImage: "doc.on.doc").labelStyle(.titleAndIcon).padding(.horizontal, 4)
            }
            .fixedSize()
            .help("Copy the result to the clipboard and close (⌘C)")
            Menu {
                Button("Save As…") { onCommand(.saveAs) }
            } label: {
                Label("Save", systemImage: "square.and.arrow.down").labelStyle(.titleAndIcon).padding(.horizontal, 4)
            } primaryAction: {
                onCommand(.save)
            }
            .buttonStyle(.borderedProminent)
            .fixedSize()
            .help("Save into the screenshot file and close (⌘S). Arrow: Save As… (⇧⌘S)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Row 2

    private var optionsRow: some View {
        let can = session.shownCapabilities
        let values = session.shownValues
        return HStack(spacing: 12) {
            if can.contains(.color) {
                HStack(spacing: 4) {
                    ForEach(RGBAColor.presets, id: \.self) { preset in
                        Button { session.apply(.color(preset)) } label: {
                            Circle()
                                .fill(Color(preset))
                                .stroke(.primary.opacity(values.color == preset ? 0.9 : 0.25),
                                        lineWidth: values.color == preset ? 2 : 1)
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                picker("Opacity", value: values.opacity, options: StyleValues.opacities, label: { "\(Int($0 * 100)) %" }) {
                    session.apply(.opacity($0))
                }
            }
            if can.contains(.width) {
                picker("Width", value: values.width, options: StyleValues.widths, label: { "\(Int($0)) px" }) {
                    session.apply(.width($0))
                }
            }
            if can.contains(.fill) {
                toggle("Fill", isOn: values.fills) { session.apply(.fill($0)) }
            }
            if can.contains(.arrow) {
                toggle("Arrowhead", isOn: values.arrow) { session.apply(.arrow($0)) }
            }
            if can.contains(.fontSize) {
                picker("Size", value: values.fontSize, options: StyleValues.fontSizes, label: { "\(Int($0))" }) {
                    session.apply(.fontSize($0))
                }
            }
            if can.contains(.textStyle) {
                toggle("Bold", isOn: values.bold) { session.apply(.bold($0)) }
                toggle("Boxed", isOn: values.boxed) { session.apply(.boxed($0)) }
            }
            if can.contains(.stepSize) {
                picker("Size", value: values.stepRadius, options: StyleValues.stepSizes, label: { "\(Int($0 * 2)) px" }) {
                    session.apply(.stepSize($0))
                }
            }
            if can.contains(.blurMode) {
                Picker("Mode", selection: Binding(get: { values.blurMode }, set: { session.apply(.blurMode($0)) })) {
                    Text("Pixelate").tag(BlurMode.pixelate)
                    Text("Blur").tag(BlurMode.blur)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            if session.tool == .crop {
                Button("Cancel") { session.cancelCrop() }
                    .disabled(session.cropDraft == nil)
                    .fixedSize()
                Button { onCommand(.confirm) } label: {
                    Label("Crop", systemImage: "crop").labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.cropDraft == nil)
                .fixedSize()
                .help("Crop to the dragged area (Enter)")
            }
            Spacer(minLength: 0)
            Text(session.tool.hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minHeight: 34)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
    }

    /// A menu of fixed values that also lists the current value when it is not one of them (e.g. after a resize).
    private func picker<Value: BinaryFloatingPoint>(_ title: String, value: Value, options: [Value],
                                                    label: @escaping (Value) -> String,
                                                    set: @escaping @MainActor (Value) -> Void) -> some View {
        let all = options.contains(value) ? options : (options + [value]).sorted()
        return Picker(title, selection: Binding(get: { value }, set: set)) {
            ForEach(all, id: \.self) { Text(label($0)).tag($0) }
        }
        .fixedSize()
    }

    private func toggle(_ title: String, isOn: Bool, set: @escaping @MainActor (Bool) -> Void) -> some View {
        Toggle(title, isOn: Binding(get: { isOn }, set: set))
            .toggleStyle(.checkbox)
            .fixedSize()
    }
}
