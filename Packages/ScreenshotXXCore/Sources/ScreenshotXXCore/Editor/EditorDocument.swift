import CoreGraphics
import Foundation
import Observation

/// The editor's model: base image, annotations, selection, undo history.
/// Live edits (dragging) change `state` without an undo entry; `commit()` records one.
@Observable
public final class EditorDocument {
    public let baseImage: CGImage
    public private(set) var state = DocumentState()
    public var selection: Set<Annotation.ID> = []
    private var history: UndoStack<DocumentState>

    public init(baseImage: CGImage) {
        self.baseImage = baseImage
        history = UndoStack(initial: DocumentState())
    }

    public var annotations: [Annotation] { state.annotations }
    public var frame: FrameStyle { state.frame }
    public var layout: CanvasLayout { CanvasLayout(imageSize: imageSize, frame: state.frame) }

    /// Live frame change (sliders). `commit()` records it.
    public func setFrame(_ frame: FrameStyle) {
        state.frame = frame
    }
    public var canUndo: Bool { history.canUndo }
    public var canRedo: Bool { history.canRedo }
    public var imageSize: CGSize { CGSize(width: baseImage.width, height: baseImage.height) }

    /// One more than the highest step number placed so far.
    public var nextStepNumber: Int {
        let highest = state.annotations.compactMap { annotation -> Int? in
            if case .step(let number, _, _) = annotation.kind { number } else { nil }
        }.max() ?? 0
        return highest + 1
    }

    public func annotation(id: Annotation.ID) -> Annotation? {
        state.annotations.first { $0.id == id }
    }

    public func add(_ annotation: Annotation) {
        state.annotations.append(annotation)
        commit()
    }

    /// Add without recording undo (a shape being drawn). `commit()` keeps it, `revert()` drops it.
    public func insert(_ annotation: Annotation) {
        state.annotations.append(annotation)
    }

    /// Throw away everything since the last commit.
    public func revert() {
        state = history.current
        pruneSelection()
    }

    /// Replace one annotation without recording undo. Call `commit()` when the gesture ends.
    public func update(_ annotation: Annotation) {
        guard let index = state.annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        state.annotations[index] = annotation
    }

    public func commit() {
        history.push(state)
    }

    public func remove(ids: Set<Annotation.ID>) {
        state.annotations.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
        commit()
    }

    public func undo() {
        if let previous = history.undo() { state = previous; pruneSelection() }
    }

    public func redo() {
        if let next = history.redo() { state = next; pruneSelection() }
    }

    /// Top-most annotation under the point, if any.
    public func hitTest(_ point: CGPoint, tolerance: CGFloat) -> Annotation.ID? {
        state.annotations.last { $0.hitTest(point, tolerance: tolerance) }?.id
    }

    public func moveSelection(by delta: CGVector) {
        for index in state.annotations.indices where selection.contains(state.annotations[index].id) {
            state.annotations[index].move(by: delta)
        }
    }

    private func pruneSelection() {
        let ids = Set(state.annotations.map(\.id))
        selection = selection.intersection(ids)
    }
}
