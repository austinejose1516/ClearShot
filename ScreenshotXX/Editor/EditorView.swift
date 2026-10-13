import AppKit
import ScreenshotXXCore
import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    let document: EditorDocument
    let state: EditorState
    let actions: EditorActions
    let fileURL: URL?
    let onSaved: (URL) -> Void
    let onEdited: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(document: document, state: state, onCopy: copy, onSave: save, onSaveAs: exportAs)
            Divider()
            EditorCanvasView(document: document, state: state)
        }
        .frame(minWidth: 1040, minHeight: 600)
        .onAppear(perform: wireShortcuts)
        .onChange(of: document.state) { onEdited(document.canUndo) }
    }

    private func wireShortcuts() {
        actions.undo = { document.undo() }
        actions.redo = { document.redo() }
        actions.delete = { document.remove(ids: document.selection) }
        actions.copy = copy
        actions.save = save
        actions.selectAll = { document.selection = Set(document.annotations.map(\.id)) }
        actions.deselect = { document.selection = []; state.tool = .select }
        actions.zoomIn = { state.zoomIsFit = false; state.zoom = min(8, state.zoom * 1.25) }
        actions.zoomOut = { state.zoomIsFit = false; state.zoom = max(0.05, state.zoom / 1.25) }
    }

    private func copy() {
        guard let image = Exporter.render(document) else { return }
        ClipboardService.copy(image)
    }

    private func save() {
        guard let url = fileURL else { exportAs(); return }
        write(to: url)
    }

    private func exportAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "ScreenshotXX.png"
        panel.directoryURL = fileURL?.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(to: url)
    }

    private func write(to url: URL) {
        guard let image = Exporter.render(document) else {
            ErrorPresenter.show(title: "Export failed", message: "The image could not be rendered.")
            return
        }
        do {
            try FileSaver.overwrite(image, format: .png, at: url)
            DiagnosticLog.write("editor saved \(image.width)x\(image.height) px to \(url.path(percentEncoded: false))")
            onSaved(url)
        } catch {
            ErrorPresenter.show(title: "Could not save", message: error.localizedDescription)
        }
    }
}
