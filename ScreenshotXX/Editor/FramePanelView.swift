import AppKit
import ScreenshotXXCore
import SwiftUI
import UniformTypeIdentifiers

/// Right-side panel: everything around the image.
struct FramePanelView: View {
    let document: EditorDocument

    var body: some View {
        let frame = document.frame
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("Background") {
                    HStack(spacing: 6) {
                        swatch(selected: frame.background == .none, help: "None") {
                            Image(systemName: "slash.circle").foregroundStyle(.secondary)
                        } action: { set { $0.background = .none } }
                        ForEach(RGBAColor.presets, id: \.self) { preset in
                            swatch(selected: frame.background == .solid(preset), help: "Solid") {
                                Circle().fill(Color(preset))
                            } action: { set { $0.background = .solid(preset) } }
                        }
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(GradientPreset.all) { preset in
                            Button {
                                set { $0.background = .gradient(preset) }
                            } label: {
                                LinearGradient(colors: [Color(preset.start), Color(preset.end)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                                    .frame(height: 34)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.accentColor, lineWidth: frame.background == .gradient(preset) ? 2 : 0))
                            }
                            .buttonStyle(.plain)
                            .help(preset.name)
                        }
                    }
                    HStack {
                        Button("Choose Image…", action: chooseImage)
                        if case .image(let url) = frame.background {
                            Text(url.lastPathComponent).font(.caption).lineLimit(1).truncationMode(.middle)
                        }
                    }
                }
                slider("Padding", value: \.padding, range: 0...240, step: 4)
                slider("Corner radius", value: \.cornerRadius, range: 0...80, step: 2)
                slider("Shadow", value: \.shadow, range: 0...100, step: 5, unit: "")
                Button("Reset frame") { set { $0 = FrameStyle() } }
                    .disabled(frame == FrameStyle())
            }
            .padding(14)
        }
        .frame(width: 272)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Pieces

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }

    private func swatch<Label: View>(selected: Bool, help: String, @ViewBuilder label: () -> Label,
                                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label()
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.accentColor, lineWidth: selected ? 2 : 0))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func slider(_ title: String, value keyPath: WritableKeyPath<FrameStyle, CGFloat>,
                        range: ClosedRange<CGFloat>, step: CGFloat, unit: String = " px") -> some View {
        let value = Int(document.frame[keyPath: keyPath])
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(value == 0 && unit.isEmpty ? "off" : "\(value)\(unit)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: liveBinding(keyPath), in: range, step: step) { editing in
                if !editing { document.commit() }
            }
        }
    }

    // MARK: - Model plumbing

    /// Live change without an undo entry (sliders, typing).
    private func liveBinding<T>(_ keyPath: WritableKeyPath<FrameStyle, T>) -> Binding<T> {
        Binding(
            get: { document.frame[keyPath: keyPath] },
            set: { newValue in
                var frame = document.frame
                frame[keyPath: keyPath] = newValue
                document.setFrame(frame)
            })
    }

    /// One-shot change with an undo entry (buttons, toggles).
    private func set(_ change: (inout FrameStyle) -> Void) {
        var frame = document.frame
        change(&frame)
        document.setFrame(frame)
        document.commit()
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        set { $0.background = .image(url) }
    }
}
