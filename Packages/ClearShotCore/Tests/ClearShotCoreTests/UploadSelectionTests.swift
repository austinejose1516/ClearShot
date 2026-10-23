import CoreGraphics
import Testing
@testable import ClearShotCore

@Suite struct UploadSelectionTests {
    let order = ["a", "b", "c", "d", "e", "f"]

    @Test func aPlainClickSelectsThatOneOnly() {
        var selection = UploadSelection()
        selection.click("b", in: order, modifiers: [])
        selection.click("d", in: order, modifiers: [])
        #expect(selection.keys == ["d"])
    }

    @Test func commandClickAddsAndRemoves() {
        var selection = UploadSelection()
        selection.click("b", in: order, modifiers: [])
        selection.click("d", in: order, modifiers: .command)
        #expect(selection.keys == ["b", "d"])
        selection.click("b", in: order, modifiers: .command)
        #expect(selection.keys == ["d"])
    }

    @Test func shiftClickSelectsTheRangeFromTheLastPlainClick() {
        var selection = UploadSelection()
        selection.click("e", in: order, modifiers: [])
        selection.click("b", in: order, modifiers: .shift)
        #expect(selection.keys == ["b", "c", "d", "e"])
    }

    @Test func shiftClickWithNothingSelectedSelectsFromTheStart() {
        var selection = UploadSelection()
        selection.click("c", in: order, modifiers: .shift)
        #expect(selection.keys == ["a", "b", "c"])
    }

    @Test func selectAllAndClear() {
        var selection = UploadSelection()
        selection.selectAll(order)
        #expect(selection.keys == Set(order))
        selection.clear()
        #expect(selection.keys.isEmpty)
    }

    @Test func keepDropsWhatIsNoLongerShown() {
        var selection = UploadSelection()
        selection.selectAll(order)
        selection.keep(in: ["b", "d"])
        #expect(selection.keys == ["b", "d"])
    }

    @Test func arrowsMoveOneCardOrOneRow() {
        var selection = UploadSelection()
        selection.click("b", in: order, modifiers: [])
        selection.move(.right, in: order, columns: 3)
        #expect(selection.keys == ["c"])
        selection.move(.down, in: order, columns: 3)
        #expect(selection.keys == ["f"])
        selection.move(.up, in: order, columns: 3)
        #expect(selection.keys == ["c"])
        selection.move(.left, in: order, columns: 3)
        #expect(selection.keys == ["b"])
    }

    @Test func arrowsStopAtTheEdges() {
        var selection = UploadSelection()
        selection.click("a", in: order, modifiers: [])
        selection.move(.left, in: order, columns: 3)
        selection.move(.up, in: order, columns: 3)
        #expect(selection.keys == ["a"])
        selection.click("e", in: order, modifiers: [])
        selection.move(.down, in: order, columns: 3)
        #expect(selection.keys == ["e"])
    }

    @Test func anArrowWithNothingSelectedSelectsTheFirst() {
        var selection = UploadSelection()
        selection.move(.right, in: order, columns: 3)
        #expect(selection.keys == ["a"])
    }

    @Test func theOnlySelectedKey() {
        var selection = UploadSelection()
        #expect(selection.only == nil)
        selection.click("c", in: order, modifiers: [])
        #expect(selection.only == "c")
        selection.click("d", in: order, modifiers: .command)
        #expect(selection.only == nil)
    }

    @Test func columnsMatchTheAdaptiveGrid() {
        // 868 pt of room: four 200-pt columns with 16-pt gaps fit (848), five (1064) do not.
        #expect(UploadSelection.columns(forWidth: 868, minimum: 200, spacing: 16) == 4)
        #expect(UploadSelection.columns(forWidth: 100, minimum: 200, spacing: 16) == 1)
    }

    @Test func aDragBoxPicksTheCardsItTouches() {
        let frames = ["a": CGRect(x: 0, y: 0, width: 100, height: 100),
                      "b": CGRect(x: 120, y: 0, width: 100, height: 100),
                      "c": CGRect(x: 0, y: 120, width: 100, height: 100)]
        #expect(UploadSelection.keys(in: CGRect(x: 90, y: 90, width: 40, height: 40), frames: frames) == ["a", "b", "c"])
        #expect(UploadSelection.keys(in: CGRect(x: 105, y: 105, width: 10, height: 10), frames: frames).isEmpty)
    }

    @Test func aDragBoxReplacesTheSelectionOrAddsToWhatWasThere() {
        var selection = UploadSelection()
        selection.click("a", in: order, modifiers: [])
        selection.box(["b", "c"], onto: [])
        #expect(selection.keys == ["b", "c"])
        selection.box(["d"], onto: ["a"])
        #expect(selection.keys == ["a", "d"])
    }
}
