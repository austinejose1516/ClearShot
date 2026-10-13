import ScreenshotXXCore
import SwiftUI

/// The inline editor, drawn at image scale where the text sits, then scaled with the canvas.
struct TextEditingOverlay: View {
    let session: EditorSession
    let transform: CanvasTransform

    @FocusState private var focused: Bool

    var body: some View {
        if let id = session.editingTextID, let annotation = session.document.annotation(id: id) {
            switch annotation.kind {
            case .text(let content):
                field(placeholder: "Type here")
                    .font(Font(content.font))
                    .underline(content.underline)
                    .foregroundStyle(content.boxed ? Color.white : Color(annotation.style.strokeColor))
                    .padding(.horizontal, content.padding.width)
                    .padding(.vertical, content.padding.height)
                    .background(content.boxed ? Color(annotation.style.strokeColor) : Color.black.opacity(0.2),
                                in: RoundedRectangle(cornerRadius: content.cornerRadius))
                    .fixedSize()
                    .placed(at: content.origin, transform: transform)
            case .bubble(let bubble):
                field(placeholder: "Say something")
                    .font(.system(size: bubble.fontSize, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .multilineTextAlignment(.center)
                    .frame(width: bubble.textRect.width)
                    .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 4))
                    .placed(at: bubble.textRect.origin, transform: transform)
            default:
                EmptyView()
            }
        }
    }

    private func field(placeholder: String) -> some View {
        TextField(placeholder, text: Binding(
            get: { session.editingTextID.flatMap { session.document.annotation(id: $0)?.editableText } ?? "" },
            set: { session.editText($0) }), axis: .vertical)
            .textFieldStyle(.plain)
            .focused($focused)
            .onAppear { focused = true }
            .onSubmit { session.finishTextEditing() }
            .onExitCommand { session.finishTextEditing() }
    }
}

private extension View {
    /// Scales an image-sized view with the canvas zoom and puts its top-left corner at `origin` (image pixels).
    func placed(at origin: CGPoint, transform: CanvasTransform) -> some View {
        let point = transform.toCanvas(origin)
        return overlay(Rectangle().stroke(.tint, style: StrokeStyle(lineWidth: 1 / transform.scale, dash: [4, 3])))
            .scaleEffect(transform.scale, anchor: .topLeading)
            .offset(x: point.x, y: point.y)
    }
}
