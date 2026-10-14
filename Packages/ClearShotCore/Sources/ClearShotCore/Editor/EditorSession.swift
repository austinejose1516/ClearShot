import CoreGraphics
import Foundation
import Observation

/// What a press at the mouse position would do, so the view can pick a cursor.
public enum CursorHint: Equatable, Sendable {
    /// A corner dot.
    case resize(HandleKind)
    /// A line end, the curve's middle dot or a bubble tail.
    case moveHandle
    case move
    case editText
    case tool(EditorTool)
}

/// One editor window's working state: the document, the active tool, the toolbar values, and what the
/// mouse is doing. The canvas view converts coordinates and forwards drags here; all decisions live here.
@Observable
public final class EditorSession {
    public let document: EditorDocument
    public var tool: EditorTool = .select {
        didSet { if tool != .crop { cropDraft = nil } }
    }
    /// What new annotations get; a toolbar change also updates these. The highlighter keeps its own set, so its
    /// wide, see-through yellow never leaks into the next arrow. Every other tool shares one set, so a colour
    /// picked for arrows also applies to the next rectangle.
    public private(set) var defaults = StyleValues()
    public private(set) var highlighterDefaults = StyleValues.highlighter
    public private(set) var editingTextID: Annotation.ID?
    public private(set) var cropDraft: CGRect?

    @ObservationIgnored private var editingTextIsNew = false
    @ObservationIgnored private var gesture: Gesture?

    private enum Gesture {
        case drawing(Annotation.ID, start: CGPoint)
        case scribbling(Annotation.ID)
        case moving(last: CGPoint)
        case reshaping(Annotation, HandleKind)
        /// Pressed on already-selected text: a click edits it, a drag moves it.
        case pressedOnSelectedText(Annotation.ID, start: CGPoint)
        /// Text goes where the press started, at the toolbar's size; a drag does not size it.
        case placingText(start: CGPoint)
        case cropping(start: CGPoint)
        case idle
    }

    public init(document: EditorDocument) {
        self.document = document
    }

    /// True while a drag moves the selection (the view shows a closed hand).
    public var isMovingSelection: Bool {
        if case .moving = gesture { true } else { false }
    }

    // MARK: - Toolbar

    public var selected: [Annotation] {
        document.annotations.filter { document.selection.contains($0.id) }
    }

    /// The values the toolbar shows: the selection's own, or the defaults.
    public var shownValues: StyleValues {
        guard let first = selected.first else { return toolbarDefaults }
        return toolbarDefaults.reading(first)
    }

    /// The defaults the toolbar shows and edits: the highlighter's while it is in use (the tool is on, or only
    /// highlights are selected), the shared ones otherwise.
    private var toolbarDefaults: StyleValues {
        get { highlighterInUse ? highlighterDefaults : defaults }
        set { if highlighterInUse { highlighterDefaults = newValue } else { defaults = newValue } }
    }

    private var highlighterInUse: Bool {
        let selected = selected
        return selected.isEmpty ? tool == .highlight : selected.allSatisfy(\.isHighlight)
    }

    /// The controls the toolbar shows: what the selection has, or what the tool makes.
    public var shownCapabilities: StyleCapabilities {
        let selected = selected
        guard !selected.isEmpty else { return tool.capabilities }
        return selected.reduce(into: StyleCapabilities()) { $0.formUnion($1.capabilities) }
    }

    /// One toolbar change: it updates the defaults, and each selected annotation where it has that property.
    /// `live` (a slider being dragged) skips the undo step; `endLiveChange()` records one for the whole drag.
    public func apply(_ change: StyleChange, live: Bool = false) {
        toolbarDefaults.apply(change)
        guard !document.selection.isEmpty else { return }
        for annotation in selected {
            var changed = annotation
            changed.apply(change)
            document.update(changed)
        }
        if !live { document.commit() }
    }

    public func endLiveChange() {
        document.commit()
    }

    // MARK: - Commands

    public func deleteSelection() {
        guard !document.selection.isEmpty else { return }
        document.remove(ids: document.selection)
    }

    public func selectAll() {
        document.selection = Set(document.annotations.map(\.id))
    }

    /// Esc: stop editing, clear the selection and any crop, back to Select.
    public func cancel() {
        finishTextEditing()
        document.selection = []
        cropDraft = nil
        tool = .select
    }

    public func applyCrop() {
        guard let crop = cropDraft else { return }
        document.applyCrop(crop)
        cropDraft = nil
        tool = .select
    }

    public func cancelCrop() {
        cropDraft = nil
    }

    // MARK: - Mouse (image coordinates; `tolerance` is how near counts as a hit, in image pixels)

    public func dragChanged(to point: CGPoint, tolerance: CGFloat) {
        guard let gesture else {
            press(at: point, tolerance: tolerance)
            return
        }
        switch gesture {
        case .drawing(let id, let start):
            guard var annotation = document.annotation(id: id),
                  let figure = tool.figure(from: start, to: point, values: defaults) else { return }
            annotation.kind = figure.asKind
            document.update(annotation)
        case .scribbling(let id):
            guard var annotation = document.annotation(id: id), case .freehand(var stroke) = annotation.kind,
                  let last = stroke.points.last, hypot(point.x - last.x, point.y - last.y) >= 1.5 else { return }
            stroke.points.append(point)
            annotation.kind = .freehand(stroke)
            document.update(annotation)
        case .moving(let last):
            document.moveSelection(by: CGVector(dx: point.x - last.x, dy: point.y - last.y))
            self.gesture = .moving(last: point)
        case .reshaping(let initial, let handle):
            var annotation = initial
            annotation.drag(handle, to: point)
            document.update(annotation)
        case .pressedOnSelectedText(_, let start):
            guard hypot(point.x - start.x, point.y - start.y) > tolerance / 2 else { return }
            document.moveSelection(by: CGVector(dx: point.x - start.x, dy: point.y - start.y))
            self.gesture = .moving(last: point)
        case .placingText:
            break
        case .cropping(let start):
            cropDraft = SelectionGeometry.normalizedRect(from: start, to: point)
        case .idle:
            break
        }
    }

    public func dragEnded() {
        defer { gesture = nil }
        switch gesture {
        case .drawing(let id, _), .scribbling(let id):
            guard let annotation = document.annotation(id: id) else { return }
            guard !annotation.isTooSmall else {
                // A plain click draws nothing: it clears the selection and hands back to the pointer.
                document.revert()
                document.selection = []
                tool = .select
                return
            }
            document.commit()
            document.selection = [id]
            if annotation.editableText != nil { startEditing(id, isNew: false) }
            handBackIfSingleUse()
        case .moving, .reshaping:
            document.commit()
        case .pressedOnSelectedText(let id, _):
            startEditing(id, isNew: false)
        case .placingText(let start):
            placeText(at: start)
        case .cropping:
            // A plain click (no draft) or a tiny drag picks nothing: back to the pointer.
            if cropDraft.map(SelectionGeometry.isUsable) != true {
                cropDraft = nil
                tool = .select
            }
        case .idle, nil:
            break
        }
    }

    public func cursor(at point: CGPoint, tolerance: CGFloat) -> CursorHint {
        if let hit = handle(at: point, tolerance: tolerance) {
            return hit.kind.isCorner ? .resize(hit.kind) : .moveHandle
        }
        if tool.grabsExisting, let id = document.hitTest(point, tolerance: tolerance, includingInterior: tool == .select),
           let annotation = document.annotation(id: id) {
            return annotation.editableText != nil && document.selection == [id] ? .editText : .move
        }
        return .tool(tool)
    }

    private func press(at point: CGPoint, tolerance: CGFloat) {
        if editingTextID != nil {
            finishTextEditing()
            gesture = .idle
            return
        }
        // A dot of a selected annotation wins over every tool.
        if let hit = handle(at: point, tolerance: tolerance), let annotation = document.annotation(id: hit.id) {
            gesture = .reshaping(annotation, hit.kind)
            return
        }
        if tool.grabsExisting, let id = document.hitTest(point, tolerance: tolerance, includingInterior: tool == .select) {
            grab(id, at: point)
            return
        }
        switch tool {
        case .select:
            document.selection = []
            gesture = .idle
        case .pen, .highlight:
            let isHighlighter = tool == .highlight
            let stroke = Annotation(kind: .freehand(Freehand(points: [point], form: isHighlighter ? .highlighter : .pen)),
                                    style: (isHighlighter ? highlighterDefaults : defaults).style(canFill: false))
            document.insert(stroke)
            gesture = .scribbling(stroke.id)
        case .text:
            gesture = .placingText(start: point)
        case .crop:
            cropDraft = nil
            gesture = .cropping(start: point)
        case .step:
            let step = Step(number: document.nextStepNumber, center: point, radius: defaults.stepRadius)
            let annotation = Annotation(kind: .step(step), style: defaults.style(canFill: false))
            document.add(annotation)
            document.selection = [annotation.id]
            gesture = .idle
        case .line, .arrow, .curve, .rect, .ellipse, .bubble, .blur:
            guard let figure = tool.figure(from: point, to: point, values: defaults) else {
                gesture = .idle
                return
            }
            let annotation = Annotation(kind: figure.asKind,
                                        style: defaults.style(canFill: tool.capabilities.contains(.fill)))
            document.insert(annotation)
            gesture = .drawing(annotation.id, start: point)
        }
    }

    private func grab(_ id: Annotation.ID, at point: CGPoint) {
        if document.selection == [id], document.annotation(id: id)?.editableText != nil {
            gesture = .pressedOnSelectedText(id, start: point)
            return
        }
        if !document.selection.contains(id) { document.selection = [id] }
        gesture = .moving(last: point)
    }

    private func handle(at point: CGPoint, tolerance: CGFloat) -> (id: Annotation.ID, kind: HandleKind)? {
        let reach = tolerance * 1.5
        for annotation in selected where annotation.id != editingTextID {
            if let handle = annotation.handles.first(where: { hypot($0.point.x - point.x, $0.point.y - point.y) <= reach }) {
                return (annotation.id, handle.kind)
            }
        }
        return nil
    }

    // MARK: - Text

    /// New text uses the toolbar's values, like a new bubble.
    private func placeText(at origin: CGPoint) {
        let content = TextContent(text: "", origin: origin, fontSize: defaults.fontSize, bold: defaults.bold,
                                  italic: defaults.italic, underline: defaults.underline, boxed: defaults.boxed)
        let annotation = Annotation(kind: .text(content), style: defaults.style(canFill: false))
        document.insert(annotation)
        document.selection = [annotation.id]
        startEditing(annotation.id, isNew: true)
        handBackIfSingleUse()
    }

    private func handBackIfSingleUse() {
        if !tool.staysActive { tool = .select }
    }

    private func startEditing(_ id: Annotation.ID, isNew: Bool) {
        editingTextID = id
        editingTextIsNew = isNew
    }

    /// Live typing in the inline editor (text or bubble). No undo step until editing finishes.
    public func editText(_ text: String) {
        guard let id = editingTextID, var annotation = document.annotation(id: id) else { return }
        annotation.setEditableText(text)
        document.update(annotation)
    }

    /// Ends inline editing. Empty text is removed (or never added, if it was new).
    public func finishTextEditing() {
        guard let id = editingTextID else { return }
        editingTextID = nil
        defer { editingTextIsNew = false }
        guard let annotation = document.annotation(id: id) else { return }
        let emptyText = annotation.textContent.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
        if emptyText {
            if editingTextIsNew { document.revert() } else { document.remove(ids: [id]) }
        } else {
            document.commit()
            document.selection = [id]
        }
    }
}
