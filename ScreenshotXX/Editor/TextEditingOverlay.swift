import ScreenshotXXCore
import SwiftUI

/// An editable field drawn where the text (or bubble text) sits, in zoomed canvas space.
struct TextEditingOverlay: View {
    let document: EditorDocument
    let id: Annotation.ID
    let transform: CanvasTransform
    let onFinish: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        if let annotation = document.annotation(id: id) {
            switch annotation.kind {
            case .text(let content):
                textField(annotation, content)
            case .speechBubble(let rect, _, let text, let fontSize):
                bubbleField(annotation, rect: rect.standardized, text: text, fontSize: fontSize)
            default:
                EmptyView()
            }
        }
    }

    private func textField(_ annotation: Annotation, _ content: TextContent) -> some View {
        let color = Color(annotation.style.strokeColor)
        let zoom = transform.scale
        let origin = transform.toCanvas(content.origin)
        return TextField("Text", text: Binding(
            get: { content.text },
            set: { newValue in
                var updated = annotation
                var text = content
                text.text = newValue
                updated.kind = .text(text)
                document.update(updated)
            }), axis: .vertical)
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
            .offset(x: origin.x, y: origin.y)
            .focused($focused)
            .onAppear { focused = true }
            .onSubmit(onFinish)
            .onExitCommand(perform: onFinish)
    }

    private func bubbleField(_ annotation: Annotation, rect: CGRect, text: String, fontSize: CGFloat) -> some View {
        let zoom = transform.scale
        let inner = CGRect(x: rect.minX + fontSize * 0.4, y: rect.minY + fontSize * 0.3,
                           width: max(1, rect.width - fontSize * 0.8), height: max(1, rect.height - fontSize * 0.6))
        let origin = transform.toCanvas(inner.origin)
        return TextField("Say something", text: Binding(
            get: { text },
            set: { newValue in
                var updated = annotation
                if case .speechBubble(let r, let tail, _, let size) = annotation.kind {
                    updated.kind = .speechBubble(rect: r, tail: tail, text: newValue, fontSize: size)
                    document.update(updated)
                }
            }), axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: fontSize * zoom, weight: .semibold))
            .foregroundStyle(Color.black)
            .multilineTextAlignment(.center)
            .frame(width: inner.width * zoom)
            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .offset(x: origin.x, y: origin.y)
            .focused($focused)
            .onAppear { focused = true }
            .onSubmit(onFinish)
            .onExitCommand(perform: onFinish)
    }
}
