import ScreenshotXXCore
import SwiftUI

/// Zoomable canvas with all mouse interaction: draw, select, move, resize.
struct EditorCanvasView: View {
    let document: EditorDocument
    let state: EditorState

    private enum Gesture {
        case drawing(Annotation.ID, start: CGPoint)
        case moving(last: CGPoint)
        case resizing(Annotation.ID, HandleKind)
        case idle
    }

    @State private var gesture: Gesture?

    var body: some View {
        GeometryReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                canvas
                    .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
            }
            .onAppear { fit(to: proxy.size) }
            .onChange(of: proxy.size) { _, newSize in fit(to: newSize) }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var canvas: some View {
        let size = document.imageSize
        let zoom = state.zoom
        return ZStack(alignment: .topLeading) {
            CompositionView(document: document)
                .scaleEffect(zoom, anchor: .topLeading)
                .frame(width: size.width * zoom, height: size.height * zoom, alignment: .topLeading)
                .clipped()
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
            SelectionOverlay(document: document, zoom: zoom)
        }
        .frame(width: size.width * zoom, height: size.height * zoom, alignment: .topLeading)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in changed(at: imagePoint(value.location)) }
                .onEnded { value in ended(at: imagePoint(value.location)) }
        )
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
        if gesture == nil { begin(at: point); return }
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
            }
            document.update(annotation)
        case .moving(let last):
            document.moveSelection(by: CGVector(dx: point.x - last.x, dy: point.y - last.y))
            gesture = .moving(last: point)
        case .resizing(let id, let handle):
            guard let annotation = document.annotation(id: id) else { return }
            document.update(Handles.apply(handle, to: annotation, point: point))
        case .idle, nil:
            break
        }
    }

    private func begin(at point: CGPoint) {
        let tolerance = 6 / state.zoom
        switch state.tool {
        case .select:
            if let hit = handleHit(at: point, tolerance: tolerance * 1.5) {
                gesture = .resizing(hit.id, hit.kind)
            } else if let id = document.hitTest(point, tolerance: tolerance) {
                if !document.selection.contains(id) { document.selection = [id] }
                gesture = .moving(last: point)
            } else {
                document.selection = []
                gesture = .idle
            }
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
        case .idle, nil:
            break
        }
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
