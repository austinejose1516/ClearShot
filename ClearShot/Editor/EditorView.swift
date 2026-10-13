import AppKit
import ClearShotCore
import SwiftUI

struct EditorView: View {
    /// Wide enough for every toolbar button and the options row, with room to spare.
    static let minimumSize = NSSize(width: 1240, height: 640)
    static let defaultSize = NSSize(width: 1280, height: 800)

    let session: EditorSession
    let viewState: EditorViewState
    let onCommand: (EditorCommand) -> Void
    let onShare: (NSView?) -> Void
    let onEdited: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(session: session, viewState: viewState, onCommand: onCommand, onShare: onShare)
            Divider()
            HStack(spacing: 0) {
                EditorCanvasView(session: session, viewState: viewState)
                if viewState.showsFramePanel {
                    Divider()
                    FramePanelView(document: session.document)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.25), value: viewState.showsFramePanel)
        }
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
        .onChange(of: session.document.canUndo) { _, edited in onEdited(edited) }
    }
}
