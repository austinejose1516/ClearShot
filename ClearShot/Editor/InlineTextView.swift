import AppKit
import SwiftUI

/// The inline editor's text view: an AppKit text view laid out at screen size, so its cursor stays crisp at any
/// zoom. It takes focus as soon as it appears, so the blinking cursor is the cue to start typing.
struct InlineTextView: NSViewRepresentable {
    let text: String
    let font: NSFont
    let color: NSColor
    var alignment: NSTextAlignment = .left
    var underline = false
    var shadow: NSShadow?
    /// Wrap to the view's width and centre the lines vertically (bubbles); otherwise lines only break at ⌘Return.
    var wraps = false
    let onChange: (String) -> Void
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> CursorTextView {
        // TextKit 1, so the cursor is drawn by `drawInsertionPoint` below.
        let view = CursorTextView(usingTextLayoutManager: false)
        view.delegate = context.coordinator
        view.drawsBackground = false
        view.isRichText = false
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        view.textContainer?.widthTracksTextView = wraps
        view.textContainer?.containerSize = NSSize(width: wraps ? 0 : CGFloat.greatestFiniteMagnitude,
                                                   height: CGFloat.greatestFiniteMagnitude)
        view.centersVertically = wraps
        view.string = text
        view.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        style(view)
        return view
    }

    func updateNSView(_ view: CursorTextView, context: Context) {
        context.coordinator.parent = self
        // Typing a composed character (e.g. an accent) keeps "marked" text; restyling it would cancel it.
        guard !view.hasMarkedText() else { return }
        if view.string != text { view.string = text }
        style(view)
    }

    private func style(_ view: CursorTextView) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        if underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if let shadow { attributes[.shadow] = shadow }
        view.typingAttributes = attributes
        view.textStorage?.setAttributes(attributes, range: NSRange(location: 0, length: view.textStorage?.length ?? 0))
        view.cursorColor = color
        view.centerText()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InlineTextView

        init(_ parent: InlineTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? CursorTextView else { return }
            view.centerText()
            parent.onChange(view.string)
        }

        /// Return and Escape finish; ⌘Return (sent by the window) and ⌥Return add a line.
        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) || selector == #selector(NSResponder.cancelOperation(_:))
            else { return false }
            parent.onFinish()
            return true
        }
    }
}

/// A text view with a rounded cursor in the text's colour, thicker for bigger text.
final class CursorTextView: NSTextView {
    var cursorColor: NSColor = .labelColor
    var centersVertically = false

    private var cursorWidth: CGFloat { max(2, ((font?.pointSize ?? 16) / 14).rounded()) }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        let cursor = NSRect(x: rect.minX, y: rect.minY, width: cursorWidth, height: rect.height)
        if flag {
            cursorColor.setFill()
            NSBezierPath(roundedRect: cursor, xRadius: cursorWidth / 2, yRadius: cursorWidth / 2).fill()
        } else {
            setNeedsDisplay(cursor, avoidAdditionalLayout: true)
        }
    }

    // AppKit erases the cursor by redrawing a 1 pt wide rect; widen it so the thicker cursor is erased too.
    override func setNeedsDisplay(_ rect: NSRect, avoidAdditionalLayout flag: Bool) {
        var rect = rect
        rect.size.width += cursorWidth
        super.setNeedsDisplay(rect, avoidAdditionalLayout: flag)
    }

    override func layout() {
        super.layout()
        centerText()
    }

    /// Bubbles: pad the top so the lines sit in the middle, like the finished bubble.
    func centerText() {
        guard centersVertically, let layoutManager, let textContainer, let font else { return }
        layoutManager.ensureLayout(for: textContainer)
        let used = max(layoutManager.usedRect(for: textContainer).height, layoutManager.defaultLineHeight(for: font))
        let inset = max(0, (bounds.height - used) / 2)
        if abs(textContainerInset.height - inset) > 0.5 { textContainerInset = NSSize(width: 0, height: inset) }
    }
}
