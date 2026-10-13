import AppKit
import ClearShotCore
import SwiftUI

struct EditorView: View {
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
                }
            }
        }
        .frame(minWidth: 1040, minHeight: 600)
        .onChange(of: session.document.canUndo) { _, edited in onEdited(edited) }
    }
}
