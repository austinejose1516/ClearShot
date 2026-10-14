import AppKit
import ClearShotCore
import SwiftUI

/// The inline editor, drawn where the text sits so typing looks like the finished annotation: the same font,
/// colour, box and alignment. Laid out at screen size (not scaled with the canvas), so the cursor stays crisp.
struct TextEditingOverlay: View {
    let session: EditorSession
    let transform: CanvasTransform

    var body: some View {
        if let id = session.editingTextID, let annotation = session.document.annotation(id: id) {
            let scale = transform.scale
            switch annotation.kind {
            case .text(let content):
                let colour = annotation.style.strokeColor
                ZStack(alignment: .topLeading) {
                    if content.boxed {
                        RoundedRectangle(cornerRadius: content.cornerRadius * scale)
                            .fill(Color(colour))
                    }
                    InlineTextView(text: content.text, font: screenFont(content.font),
                                   color: content.boxed ? .white : NSColor(Color(colour)),
                                   underline: content.underline, shadow: content.boxed ? nil : shadow(content.fontSize),
                                   onChange: session.editText, onFinish: session.finishTextEditing)
                        // A little wider than measured, so AppKit never wraps or clips the last letter.
                        .frame(width: content.textSize.width * scale + 8, height: content.textSize.height * scale)
                        .offset(x: content.padding.width * scale, y: content.padding.height * scale)
                }
                .placed(in: content.frame, transform: transform)
            case .bubble(let bubble):
                InlineTextView(text: bubble.text, font: screenFont(bubble.font), color: .black, alignment: .center,
                               wraps: true, onChange: session.editText, onFinish: session.finishTextEditing)
                    .placed(in: bubble.textRect, transform: transform)
            default:
                EmptyView()
            }
        }
    }

    /// The annotation's font at its size on screen.
    private func screenFont(_ font: CTFont) -> NSFont {
        CTFontCreateCopyWithAttributes(font, CTFontGetSize(font) * transform.scale, nil, nil) as NSFont
    }

    /// The soft shadow plain text has when finished (see TextAnnotationView), at screen size.
    private func shadow(_ fontSize: CGFloat) -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = .black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = fontSize * 0.06 * transform.scale
        shadow.shadowOffset = NSSize(width: 0, height: -transform.scale)
        return shadow
    }
}

private extension View {
    /// Sizes the view to `rect` (image pixels) on screen, outlines it, and puts it there.
    func placed(in rect: CGRect, transform: CanvasTransform) -> some View {
        let shown = transform.toCanvas(rect)
        return frame(width: shown.width, height: shown.height, alignment: .topLeading)
            .overlay(Rectangle().stroke(.tint, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .offset(x: shown.minX, y: shown.minY)
    }
}
