import ScreenshotXXCore
import SwiftUI

/// An editable field drawn exactly where the text annotation sits, in zoomed canvas space.
struct TextEditingOverlay: View {
    let document: EditorDocument
    let id: Annotation.ID
    let zoom: CGFloat
    let onFinish: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        if let annotation = document.annotation(id: id), case .text(let content) = annotation.kind {
            let color = Color(annotation.style.strokeColor)
            TextField("Text", text: binding(annotation, content), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: content.fontSize * zoom, weight: content.bold ? .bold : .medium))
                .foregroundStyle(content.boxed ? Color.white : color)
                .padding(.horizontal, content.boxPadding * zoom)
                .padding(.vertical, content.boxPadding * zoom / 2)
                .background(content.boxed ? color : Color.black.opacity(0.25),
                            in: RoundedRectangle(cornerRadius: content.fontSize * 0.25 * zoom))
                .overlay(RoundedRectangle(cornerRadius: content.fontSize * 0.25 * zoom)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                .fixedSize()
                .offset(x: content.origin.x * zoom, y: content.origin.y * zoom)
                .focused($focused)
                .onAppear { focused = true }
                .onSubmit(onFinish)
                .onExitCommand(perform: onFinish)
        }
    }

    private func binding(_ annotation: Annotation, _ content: TextContent) -> Binding<String> {
        Binding(
            get: { content.text },
            set: { newValue in
                var updated = annotation
                var text = content
                text.text = newValue
                updated.kind = .text(text)
                document.update(updated)
            })
    }
}
