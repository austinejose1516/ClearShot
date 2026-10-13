import AppKit
import ClearShotCore
import SwiftUI

/// Two fixed-height rows (so the canvas never jumps): tools and file actions on top; below, only the
/// settings that apply to the tool or the selection.
struct EditorToolbar: View {
    let session: EditorSession
    let viewState: EditorViewState
    let onCommand: (EditorCommand) -> Void
    /// Share needs the button's AppKit view, so the Share menu can open under it.
    let onShare: (NSView?) -> Void

    /// The colour panel reports every small move; this records one undo step once it settles.
    @State private var colourCommit: Task<Void, Never>?
    @State private var shareAnchor = AnchorHolder()

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            Divider()
            optionsRow
        }
        .background(.bar)
    }

    // MARK: - Row 1: tools and actions

    private var mainRow: some View {
        @Bindable var viewState = viewState
        return HStack(spacing: 8) {
            ForEach(Array(EditorTool.groups.enumerated()), id: \.offset) { _, group in
                Group {
                    ForEach(group) { tool in
                        ToolButton(symbol: tool.symbol, help: tool.title, isOn: session.tool == tool) {
                            session.tool = tool
                            viewState.showTip(tool.hint)
                        }
                    }
                }
                .grouped()
            }
            Group {
                ToolButton(symbol: "arrow.uturn.backward", help: "Undo (⌘Z)") { onCommand(.undo) }
                    .disabled(!session.document.canUndo)
                ToolButton(symbol: "arrow.uturn.forward", help: "Redo (⇧⌘Z)") { onCommand(.redo) }
                    .disabled(!session.document.canRedo)
                ToolButton(symbol: "trash", help: "Delete (⌫)") { onCommand(.delete) }
                    .disabled(session.document.selection.isEmpty)
            }
            .grouped()
            Menu {
                Picker("Zoom", selection: $viewState.canvasZoom.mode) {
                    Text("Fit").tag(CanvasZoom.Mode.fit)
                    Text("50 %").tag(CanvasZoom.Mode.scale(0.5))
                    Text("100 %").tag(CanvasZoom.Mode.scale(1))
                    Text("200 %").tag(CanvasZoom.Mode.scale(2))
                }
                .pickerStyle(.inline)
                Divider()
                Button("Zoom In") { onCommand(.zoomIn) }
                Button("Zoom Out") { onCommand(.zoomOut) }
            } label: {
                Text(viewState.canvasZoom.label).monospacedDigit()
            }
            .fixedSize()
            .help("Zoom (⌘+ / ⌘−)")
            Spacer(minLength: 12)
            Toggle(isOn: $viewState.showsFramePanel) {
                Label("Frame", systemImage: "sidebar.right").labelStyle(.titleAndIcon)
            }
            .toggleStyle(.button)
            .buttonBorderShape(.capsule)
            .fixedSize()
            .help("Background, padding, corners and shadow")
            .onChange(of: viewState.showsFramePanel) { _, shown in
                if shown, session.document.frame == session.document.initialFrame {
                    session.document.setFrame(.starter)
                    session.document.commit()
                }
            }
            Button { onCommand(.upload) } label: {
                if let progress = viewState.uploadProgress {
                    ProgressView(value: progress).progressViewStyle(.linear).frame(width: 64).padding(.horizontal, 4)
                } else {
                    Label("Upload", systemImage: "icloud.and.arrow.up").labelStyle(.titleAndIcon).padding(.horizontal, 2)
                }
            }
            .buttonBorderShape(.capsule)
            .fixedSize()
            .disabled(viewState.uploadProgress != nil)
            .help("Upload to your cloud bucket, copy the link and close (set up in Settings → Cloud)")
            Button { onShare(shareAnchor.view) } label: {
                Label("Share", systemImage: "square.and.arrow.up").labelStyle(.titleAndIcon).padding(.horizontal, 2)
            }
            .buttonBorderShape(.capsule)
            .fixedSize()
            .background(AnchorView(holder: shareAnchor))
            .help("Share the result (the editor stays open)")
            Button { onCommand(.copy) } label: {
                Label("Copy", systemImage: "doc.on.doc").labelStyle(.titleAndIcon).padding(.horizontal, 2)
            }
            .buttonBorderShape(.capsule)
            .fixedSize()
            .help("Copy the result and close (⌘C)")
            Menu {
                Button("Save As…") { onCommand(.saveAs) }
            } label: {
                Label("Save", systemImage: "square.and.arrow.down").labelStyle(.titleAndIcon).padding(.horizontal, 2)
            } primaryAction: {
                onCommand(.save)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .fixedSize()
            .help("Save and close (⌘S). Arrow: Save As… (⇧⌘S)")
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
    }

    // MARK: - Row 2: settings for the tool or selection

    private var optionsRow: some View {
        let can = session.shownCapabilities
        let values = session.shownValues
        return HStack(spacing: 8) {
            if can.contains(.color) {
                ColourDropdown(color: values.color, onPick: { session.apply(.color($0)) }, onCustom: pickCustom)
                labelled("Opacity") {
                    menuPicker(Binding(get: { values.opacity }, set: { session.apply(.opacity($0)) }),
                               options: StyleValues.opacities, label: { "\(Int($0 * 100)) %" })
                }
            }
            if can.contains(.width) {
                labelled("Width") {
                    Slider(value: Binding(get: { values.width }, set: { session.apply(.width($0.rounded()), live: true) }),
                           in: StyleValues.widthRange) { editing in
                        if !editing { session.endLiveChange() }
                    }
                    .frame(width: 100)
                    Text("\(Int(values.width)) px")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .leading)
                }
            }
            if can.contains(.corners) {
                labelled("Corners") {
                    menuPicker(Binding(get: { values.cornerRadius }, set: { session.apply(.cornerRadius($0)) }),
                               options: StyleValues.cornerRadii, label: { $0 == 0 ? "Square" : "\(Int($0)) px" })
                }
            }
            if can.contains(.fill) {
                toggle("Fill", isOn: Binding(get: { values.fills }, set: { session.apply(.fill($0)) })).chip()
            }
            if can.contains(.arrow) {
                toggle("Arrowhead", isOn: Binding(get: { values.arrow }, set: { session.apply(.arrow($0)) })).chip()
            }
            if can.contains(.fontSize) {
                labelled("Size") {
                    menuPicker(Binding(get: { values.fontSize }, set: { session.apply(.fontSize($0)) }),
                               options: StyleValues.fontSizes, label: { "\(Int($0))" })
                }
            }
            if can.contains(.textStyle) {
                HStack(spacing: 1) {
                    ToolButton(symbol: "bold", help: "Bold (⌘B)", isOn: values.bold) { session.apply(.bold(!values.bold)) }
                    ToolButton(symbol: "italic", help: "Italic (⌘I)", isOn: values.italic) { session.apply(.italic(!values.italic)) }
                    ToolButton(symbol: "underline", help: "Underline (⌘U)", isOn: values.underline) {
                        session.apply(.underline(!values.underline))
                    }
                }
                .chip()
                toggle("Boxed", isOn: Binding(get: { values.boxed }, set: { session.apply(.boxed($0)) })).chip()
            }
            if can.contains(.stepSize) {
                labelled("Size") {
                    menuPicker(Binding(get: { values.stepRadius }, set: { session.apply(.stepSize($0)) }),
                               options: StyleValues.stepSizes, label: { "\(Int($0 * 2)) px" })
                }
            }
            if can.contains(.blurMode) {
                Picker("Mode", selection: Binding(get: { values.blurMode }, set: { session.apply(.blurMode($0)) })) {
                    Text("Pixelate").tag(BlurMode.pixelate)
                    Text("Blur").tag(BlurMode.blur)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            if session.tool == .crop {
                Button("Cancel") { session.cancelCrop() }
                    .buttonBorderShape(.capsule)
                    .disabled(session.cropDraft == nil)
                    .fixedSize()
                Button { onCommand(.confirm) } label: {
                    Label("Crop", systemImage: "crop").labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(session.cropDraft == nil)
                .fixedSize()
                .help("Crop to the dragged area (Enter)")
            }
            Spacer(minLength: 8)
            Text(session.tool.hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(-1)
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .frame(height: 40)
    }

    // MARK: - Pieces

    private func labelled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 6) {
            Text(title).foregroundStyle(.secondary)
            content()
        }
        .chip()
    }

    /// A menu of fixed values that also lists the current value when it is not one of them (e.g. after a resize).
    /// Takes a ready Binding: passing a main-actor closure into Binding crashes the Swift 6.3 compiler.
    private func menuPicker<Value: BinaryFloatingPoint>(_ selection: Binding<Value>, options: [Value],
                                                        label: @escaping (Value) -> String) -> some View {
        let value = selection.wrappedValue
        let all = options.contains(value) ? options : (options + [value]).sorted()
        return Picker("", selection: selection) {
            ForEach(all, id: \.self) { Text(label($0)).tag($0) }
        }
        .labelsHidden()
        .fixedSize()
    }

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(.checkbox)
            .fixedSize()
    }

    private func pickCustom(_ colour: RGBAColor) {
        session.apply(.color(colour), live: true)
        colourCommit?.cancel()
        colourCommit = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            session.endLiveChange()
        }
    }
}

/// A tool or action icon: plain, or a filled accent chip with a white icon when on.
private struct ToolButton: View {
    let symbol: String
    let help: String
    var isOn = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13.5, weight: .medium))
                .frame(width: 30, height: 26)
                .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .background {
                    if isOn {
                        RoundedRectangle(cornerRadius: 7).fill(.tint)
                    } else if hovering && isEnabled {
                        RoundedRectangle(cornerRadius: 7).fill(.primary.opacity(0.08))
                    }
                }
                .contentShape(Rectangle())
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// The current colour as a dot. Click it and the palette and a custom colour picker unfold to its right, inside
/// the same chip, so the row stays short when closed and nothing ever leaves the window.
private struct ColourDropdown: View {
    let color: RGBAColor
    let onPick: (RGBAColor) -> Void
    let onCustom: (RGBAColor) -> Void

    @State private var isOpen = false

    var body: some View {
        HStack(spacing: 5) {
            Button { isOpen.toggle() } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(color))
                        .overlay(Circle().stroke(.primary.opacity(0.18), lineWidth: 0.5))
                        .frame(width: 15, height: 15)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Colour")
            if isOpen {
                Divider().frame(height: 14)
                ForEach(RGBAColor.presets, id: \.self) { preset in
                    Swatch(color: preset, isOn: color == preset) {
                        onPick(preset)
                        isOpen = false
                    }
                }
                ColorPicker("Custom colour", selection: Binding(
                    get: { Color(color) },
                    set: { onCustom(RGBAColor($0).withAlpha(1)) }), supportsOpacity: false)
                    .labelsHidden()
                    .help("Pick any colour")
            }
        }
        .chip()
        .animation(.easeOut(duration: 0.15), value: isOpen)
    }
}

private struct Swatch: View {
    let color: RGBAColor
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(color))
                .overlay(Circle().stroke(.primary.opacity(0.18), lineWidth: 0.5))
                .frame(width: 15, height: 15)
                .padding(2.5)
                .overlay(Circle().stroke(.tint, lineWidth: isOn ? 2 : 0))
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    /// A rounded group behind a set of tool buttons.
    func grouped() -> some View {
        HStack(spacing: 1) { self }
            .padding(3)
            .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
    }

    /// A soft capsule behind one setting in the second row.
    func chip() -> some View {
        padding(.horizontal, 9)
            .frame(height: 28)
            .background(.quaternary.opacity(0.55), in: Capsule())
    }
}
