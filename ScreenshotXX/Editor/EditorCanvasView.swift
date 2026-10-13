import AppKit
import ScreenshotXXCore
import SwiftUI

/// The zoomable canvas. It draws the document and forwards the mouse to `EditorSession`, in image pixels.
struct EditorCanvasView: View {
    let session: EditorSession
    let viewState: EditorViewState

    /// How near counts as a hit: 6 screen points, in image pixels.
    private var tolerance: CGFloat { 6 / viewState.zoom }

    private var transform: CanvasTransform {
        CanvasTransform(layout: session.document.layout, zoom: viewState.zoom)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                canvas.frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
            }
            .onAppear { viewState.fit(canvas: session.document.layout.canvasSize, in: proxy.size) }
            .onChange(of: proxy.size) { _, size in viewState.fit(canvas: session.document.layout.canvasSize, in: size) }
            .onChange(of: session.document.layout.canvasSize) { _, canvas in viewState.fit(canvas: canvas, in: proxy.size) }
            .overlay(alignment: .top) { tipBanner }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var canvas: some View {
        let zoom = viewState.zoom
        let canvasSize = session.document.layout.canvasSize
        let shown = CGSize(width: canvasSize.width * zoom, height: canvasSize.height * zoom)
        let transform = transform
        return ZStack(alignment: .topLeading) {
            CompositionView(document: session.document, hiddenAnnotationID: session.editingTextID)
                .scaleEffect(zoom, anchor: .topLeading)
                .frame(width: shown.width, height: shown.height, alignment: .topLeading)
                .clipped()
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
            SelectionOverlay(document: session.document, transform: transform, hiddenID: session.editingTextID)
            if let draft = session.textDraft {
                let rect = transform.toCanvas(draft)
                Rectangle()
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .background(Color.accentColor.opacity(0.08))
                    .frame(width: max(1, rect.width), height: max(1, rect.height))
                    .offset(x: rect.minX, y: rect.minY)
            }
            if let crop = session.cropDraft {
                let rect = transform.toCanvas(crop)
                DimLayer(size: shown, hole: rect)
                Rectangle()
                    .stroke(.white, lineWidth: 1.5)
                    .frame(width: max(1, rect.width), height: max(1, rect.height))
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
        .frame(width: shown.width, height: shown.height, alignment: .topLeading)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                NSCursor.for(session.cursor(at: transform.fromCanvas(location), tolerance: tolerance)).set()
            case .ended:
                NSCursor.arrow.set()
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    viewState.dismissTip()
                    session.dragChanged(to: transform.fromCanvas(value.location), tolerance: tolerance)
                    if session.isMovingSelection { NSCursor.closedHand.set() }
                }
                .onEnded { _ in session.dragEnded() }
        )
        .overlay(alignment: .topLeading) {
            // Above the gesture layer, so clicks inside the field reach the field.
            if session.editingTextID != nil {
                TextEditingOverlay(session: session, transform: transform)
            }
        }
        .padding(24)
    }

    // MARK: - Tip

    @ViewBuilder private var tipBanner: some View {
        if let tip = viewState.tip {
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

extension NSCursor {
    static func `for`(_ hint: CursorHint) -> NSCursor {
        switch hint {
        case .resize(.topLeft): .frameResize(position: .topLeft, directions: .all)
        case .resize(.topRight): .frameResize(position: .topRight, directions: .all)
        case .resize(.bottomLeft): .frameResize(position: .bottomLeft, directions: .all)
        case .resize: .frameResize(position: .bottomRight, directions: .all)
        case .moveHandle: .crosshair
        case .move: .openHand
        case .editText: .iBeam
        case .tool(.select): .arrow
        case .tool(.text): .iBeam
        case .tool(.step): .pointingHand
        case .tool: .crosshair
        }
    }
}
