import ScreenshotXXCore
import SwiftUI

/// Zoomable canvas with all mouse interaction: draw, select, move, resize.
struct EditorCanvasView: View {
    let document: EditorDocument
    let state: EditorState

    private enum Gesture {
        case drawing(Annotation.ID, start: CGPoint)
        case moving(last: CGPoint)
        case resizing(Annotation.ID, HandleKind, initial: Annotation)
        /// Pressed on an already-selected text: a click edits it, a drag moves it.
        case pendingTextEdit(Annotation.ID, start: CGPoint)
        /// Text tool on empty space: drag out the box the text should fill.
        case sizingText(start: CGPoint)
        case idle
    }

    @State private var gesture: Gesture?
    @State private var textDraft: CGRect?
    @State private var tip: String?
    @State private var tipTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                canvas
                    .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
            }
            .onAppear { fit(to: proxy.size) }
            .onChange(of: proxy.size) { _, newSize in fit(to: newSize) }
            .overlay(alignment: .top) {
                if let tip {
                    Text(tip)
                        .font(.callout)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.top, 14)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
        .onChange(of: state.tool) { showTip(for: state.tool) }
    }

    private var canvas: some View {
        let size = document.imageSize
        let zoom = state.zoom
        return ZStack(alignment: .topLeading) {
            CompositionView(document: document, hiddenAnnotationID: state.editingTextID)
                .scaleEffect(zoom, anchor: .topLeading)
                .frame(width: size.width * zoom, height: size.height * zoom, alignment: .topLeading)
                .clipped()
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
            SelectionOverlay(document: document, zoom: zoom, hiddenID: state.editingTextID)
            if let draft = textDraft {
                Rectangle()
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .background(Color.accentColor.opacity(0.08))
                    .frame(width: max(1, draft.width * zoom), height: max(1, draft.height * zoom))
                    .offset(x: draft.minX * zoom, y: draft.minY * zoom)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width * zoom, height: size.height * zoom, alignment: .topLeading)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location): cursor(at: imagePoint(location)).set()
            case .ended: NSCursor.arrow.set()
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in changed(at: imagePoint(value.location)) }
                .onEnded { value in ended(at: imagePoint(value.location)) }
        )
        .overlay(alignment: .topLeading) {
            // Above the gesture layer, so clicks inside the field reach the field.
            if let editing = state.editingTextID {
                TextEditingOverlay(document: document, id: editing, zoom: zoom, onFinish: finishTextEditing)
            }
        }
        .padding(24)
    }

    private func imagePoint(_ local: CGPoint) -> CGPoint {
        CGPoint(x: local.x / state.zoom, y: local.y / state.zoom)
    }

    private func fit(to viewport: CGSize) {
        guard state.zoomIsFit else { return }
        state.zoom = state.fitZoom(imageSize: document.imageSize, viewport: viewport)
    }

    // MARK: - Gesture handling (image coordinates)

    private func changed(at point: CGPoint) {
        if gesture == nil {
            dismissTip()
            begin(at: point)
            return
        }
        switch gesture {
        case .drawing(let id, let start):
            guard var annotation = document.annotation(id: id) else { return }
            switch annotation.kind {
            case .line(_, _, let a, let b):
                annotation.kind = .line(start: start, end: point, arrowStart: a, arrowEnd: b)
            case .rect:
                annotation.kind = .rect(SelectionGeometry.normalizedRect(from: start, to: point))
            case .ellipse:
                annotation.kind = .ellipse(SelectionGeometry.normalizedRect(from: start, to: point))
            case .freehand(var points):
                if let last = points.last, hypot(point.x - last.x, point.y - last.y) < 1.5 { return }
                points.append(point)
                annotation.kind = .freehand(points: points)
            case .curve(_, _, _, let arrowEnd):
                // Bend by a quarter of the length so the curve is visible right away; the middle handle adjusts it.
                let dx = point.x - start.x, dy = point.y - start.y
                let control = CGPoint(x: (start.x + point.x) / 2 - dy * 0.25, y: (start.y + point.y) / 2 + dx * 0.25)
                annotation.kind = .curve(start: start, control: control, end: point, arrowEnd: arrowEnd)
            case .text:
                return
            }
            document.update(annotation)
        case .moving(let last):
            document.moveSelection(by: CGVector(dx: point.x - last.x, dy: point.y - last.y))
            gesture = .moving(last: point)
            NSCursor.closedHand.set()
        case .resizing(_, let handle, let initial):
            document.update(Handles.apply(handle, to: initial, point: point))
        case .pendingTextEdit(_, let start):
            if hypot(point.x - start.x, point.y - start.y) > 3 / state.zoom {
                document.moveSelection(by: CGVector(dx: point.x - start.x, dy: point.y - start.y))
                gesture = .moving(last: point)
            }
        case .sizingText(let start):
            textDraft = SelectionGeometry.normalizedRect(from: start, to: point)
        case .idle, nil:
            break
        }
    }

    private func begin(at point: CGPoint) {
        let tolerance = 6 / state.zoom
        let handle = handleHit(at: point, tolerance: tolerance * 1.5)
        let hitID = document.hitTest(point, tolerance: tolerance)
        DiagnosticLog.write("canvas click tool=\(state.tool.rawValue) at=(\(Int(point.x)),\(Int(point.y))) zoom=\(String(format: "%.2f", state.zoom)) hit=\(hitID.map { String($0.uuidString.prefix(4)) } ?? "none") handle=\(handle.map { "\($0.kind)" } ?? "none") selected=\(document.selection.map { String($0.uuidString.prefix(4)) }) editing=\(state.editingTextID != nil) shapes=\(document.annotations.map { "\(shortKind($0)) \($0.bounds.integral)" })")
        if state.editingTextID != nil {
            finishTextEditing()
            gesture = .idle
            return
        }
        // A visible handle wins over every tool.
        if let hit = handle, let initial = document.annotation(id: hit.id) {
            gesture = .resizing(hit.id, hit.kind, initial: initial)
            return
        }
        switch state.tool {
        case .select:
            if let id = hitID {
                if document.selection == [id], let hit = document.annotation(id: id), case .text = hit.kind {
                    gesture = .pendingTextEdit(id, start: point)
                    return
                }
                if !document.selection.contains(id) {
                    document.selection = [id]
                    if let hit = document.annotation(id: id) { state.adopt(hit) }
                }
                gesture = .moving(last: point)
            } else {
                document.selection = []
                gesture = .idle
            }
        case .curve:
            let annotation = Annotation(kind: .curve(start: point, control: point, end: point, arrowEnd: true), style: state.style)
            document.insert(annotation)
            gesture = .drawing(annotation.id, start: point)
        case .text:
            if let id = hitID, let hit = document.annotation(id: id), case .text = hit.kind {
                if !document.selection.contains(id) {
                    document.selection = [id]
                    state.adopt(hit)
                }
                gesture = .pendingTextEdit(id, start: point)
                return
            }
            gesture = .sizingText(start: point)
        case .line, .arrow:
            let annotation = Annotation(kind: .line(start: point, end: point, arrowStart: false, arrowEnd: state.tool == .arrow),
                                        style: state.style)
            document.insert(annotation)
            gesture = .drawing(annotation.id, start: point)
        case .pen:
            let annotation = Annotation(kind: .freehand(points: [point]), style: state.style)
            document.insert(annotation)
            gesture = .drawing(annotation.id, start: point)
        case .rect, .ellipse:
            let rect = CGRect(origin: point, size: .zero)
            let annotation = Annotation(kind: state.tool == .rect ? .rect(rect) : .ellipse(rect), style: state.style)
            document.insert(annotation)
            gesture = .drawing(annotation.id, start: point)
        }
    }

    private func ended(at point: CGPoint) {
        defer { gesture = nil }
        switch gesture {
        case .drawing(let id, _):
            guard let annotation = document.annotation(id: id) else { return }
            let b = annotation.bounds
            let tooSmall: Bool
            if case .freehand(let points) = annotation.kind { tooSmall = points.count < 2 } else { tooSmall = max(b.width, b.height) < 3 }
            if tooSmall {
                document.revert()
            } else {
                document.commit()
                document.selection = [id]
            }
        case .moving, .resizing:
            document.commit()
        case .pendingTextEdit(let id, _):
            startTextEditing(id, isNew: false)
        case .sizingText(let start):
            let draft = textDraft
            textDraft = nil
            placeText(at: start, box: draft)
        case .idle, nil:
            break
        }
    }

    /// A dragged box sets the font size from its height; a plain click uses the toolbar size.
    private func placeText(at point: CGPoint, box: CGRect?) {
        var origin = point
        if let box, box.height >= 12 {
            origin = box.origin
            state.fontSize = TextContent.fontSize(forBoxHeight: box.height, boxed: state.boxed)
        }
        let content = TextContent(text: "Text", origin: origin, fontSize: state.fontSize, bold: state.bold, boxed: state.boxed)
        let annotation = Annotation(kind: .text(content), style: state.style)
        document.insert(annotation)
        document.selection = [annotation.id]
        startTextEditing(annotation.id, isNew: true)
    }

    // MARK: - Cursor and tip

    /// What a press here would do, as a cursor: resize on a dot, hand on a shape, I-beam on text, else the tool's cursor.
    private func cursor(at point: CGPoint) -> NSCursor {
        let tolerance = 6 / state.zoom
        if let hit = handleHit(at: point, tolerance: tolerance * 1.5) {
            switch hit.kind {
            case .topLeft: return .frameResize(position: .topLeft, directions: .all)
            case .topRight: return .frameResize(position: .topRight, directions: .all)
            case .bottomLeft: return .frameResize(position: .bottomLeft, directions: .all)
            case .bottomRight: return .frameResize(position: .bottomRight, directions: .all)
            case .lineStart, .lineEnd, .curveControl: return .crosshair
            }
        }
        if state.tool == .select || state.tool == .text,
           let id = document.hitTest(point, tolerance: tolerance), let hit = document.annotation(id: id) {
            if case .text = hit.kind { return document.selection.contains(id) ? .iBeam : .openHand }
            return state.tool == .select ? .openHand : .iBeam
        }
        switch state.tool {
        case .select: return .arrow
        case .text: return .iBeam
        default: return .crosshair
        }
    }

    private func showTip(for tool: EditorTool) {
        let text: String
        switch tool {
        case .select: text = "Click to select · drag to move · drag a dot to resize"
        case .line, .arrow: text = "Drag to draw"
        case .curve: text = "Drag to draw, then drag the middle dot to bend"
        case .pen: text = "Drag to draw freehand"
        case .rect, .ellipse: text = "Drag to draw · Fill makes it solid"
        case .text: text = "Drag to draw a text box, then type · click existing text to edit"
        }
        tipTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { tip = text }
        tipTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            dismissTip()
        }
    }

    private func dismissTip() {
        tipTask?.cancel()
        guard tip != nil else { return }
        withAnimation(.easeIn(duration: 0.2)) { tip = nil }
    }

    private func shortKind(_ annotation: Annotation) -> String {
        switch annotation.kind {
        case .line: "line"
        case .freehand: "pen"
        case .rect: "rect"
        case .ellipse: "ellipse"
        case .curve: "curve"
        case .text(let content): "text(\(content.text.prefix(8)), measured=\(content.measuredSize != .zero))"
        }
    }

    private func startTextEditing(_ id: Annotation.ID, isNew: Bool) {
        DiagnosticLog.write("text editing start new=\(isNew)")
        state.editingTextID = id
        state.editingTextIsNew = isNew
    }

    private func finishTextEditing() {
        guard let id = state.editingTextID else { return }
        DiagnosticLog.write("text editing finish")
        state.editingTextID = nil
        guard let annotation = document.annotation(id: id), case .text(let content) = annotation.kind else { return }
        if content.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if state.editingTextIsNew { document.revert() } else { document.remove(ids: [id]) }
        } else {
            document.commit()
            document.selection = [id]
        }
        state.editingTextIsNew = false
    }

    private func handleHit(at point: CGPoint, tolerance: CGFloat) -> (id: Annotation.ID, kind: HandleKind)? {
        for id in document.selection {
            guard let annotation = document.annotation(id: id) else { continue }
            for handle in Handles.positions(for: annotation)
            where hypot(handle.point.x - point.x, handle.point.y - point.y) <= tolerance {
                return (id, handle.kind)
            }
        }
        return nil
    }
}
