import CoreGraphics
import Testing
@testable import ScreenshotXXCore

@Suite struct EditorDocumentTests {
    private func pixel() -> CGImage {
        let context = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Annotation {
        Annotation(kind: .rect(CGRect(x: x, y: y, width: w, height: h)))
    }

    @Test func addIsOneUndoStep() {
        let doc = EditorDocument(baseImage: pixel())
        doc.add(rect(0, 0, 10, 10))
        #expect(doc.annotations.count == 1)
        doc.undo()
        #expect(doc.annotations.isEmpty)
        doc.redo()
        #expect(doc.annotations.count == 1)
    }

    @Test func liveUpdatesCollapseIntoOneUndoStep() {
        let doc = EditorDocument(baseImage: pixel())
        var shape = rect(0, 0, 10, 10)
        doc.add(shape)
        for step in 1...3 {
            shape.kind = .rect(CGRect(x: CGFloat(step), y: 0, width: 10, height: 10))
            doc.update(shape)
        }
        doc.commit()
        #expect(doc.annotation(id: shape.id)?.bounds.minX == 3)
        doc.undo()
        #expect(doc.annotation(id: shape.id)?.bounds.minX == 0)
    }

    @Test func removeDropsSelectedAnnotationsAndClearsSelection() {
        let doc = EditorDocument(baseImage: pixel())
        let a = rect(0, 0, 10, 10), b = rect(20, 20, 10, 10)
        doc.add(a); doc.add(b)
        doc.selection = [a.id]
        doc.remove(ids: doc.selection)
        #expect(doc.annotations.map(\.id) == [b.id])
        #expect(doc.selection.isEmpty)
    }

    @Test func hitTestReturnsTheTopMostAnnotation() {
        let doc = EditorDocument(baseImage: pixel())
        let below = Annotation(kind: .rect(CGRect(x: 0, y: 0, width: 100, height: 100)), style: .init(fillColor: .blue))
        let above = Annotation(kind: .rect(CGRect(x: 40, y: 40, width: 20, height: 20)), style: .init(fillColor: .red))
        doc.add(below); doc.add(above)
        #expect(doc.hitTest(CGPoint(x: 50, y: 50), tolerance: 2) == above.id)
        #expect(doc.hitTest(CGPoint(x: 10, y: 10), tolerance: 2) == below.id)
        #expect(doc.hitTest(CGPoint(x: 500, y: 500), tolerance: 2) == nil)
    }

    @Test func moveSelectionThenCommitIsUndoable() {
        let doc = EditorDocument(baseImage: pixel())
        let shape = rect(0, 0, 10, 10)
        doc.add(shape)
        doc.selection = [shape.id]
        doc.moveSelection(by: CGVector(dx: 5, dy: 7))
        doc.commit()
        #expect(doc.annotation(id: shape.id)?.bounds.origin == CGPoint(x: 5, y: 7))
        doc.undo()
        #expect(doc.annotation(id: shape.id)?.bounds.origin == .zero)
    }

    @Test func insertIsLiveUntilCommittedAndRevertDropsIt() {
        let doc = EditorDocument(baseImage: pixel())
        let shape = rect(0, 0, 10, 10)
        doc.insert(shape)
        #expect(doc.annotations.count == 1)
        #expect(doc.canUndo == false)
        doc.revert()
        #expect(doc.annotations.isEmpty)
        doc.insert(shape)
        doc.commit()
        #expect(doc.canUndo == true)
        doc.undo()
        #expect(doc.annotations.isEmpty)
    }
}
