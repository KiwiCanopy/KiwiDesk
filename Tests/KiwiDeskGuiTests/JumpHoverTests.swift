import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The pointer lifts, the keys and a click select (#2365): a real
/// pointer move lifts the item under it grey and never moves the
/// green selection; a row or tile sliding under a still pointer —
/// the panel opening there, a re-rank, a scroll — lifts nothing
/// (#2229).
@Suite("KiwiHub hover")
@MainActor
struct JumpHoverTests {
    private func model() -> JumpModel {
        let model = JumpModel(
            snapshot: JumpSnapshot(
                entries: [
                    JumpListTests.row(1, "Mail", "Inbox"),
                    JumpListTests.row(2, "Notes", "Ideas"),
                ],
                here: "1",
                hereIcon: nil
            ),
            icons: [:],
            rowCap: 8,
            pointer: CGPoint(x: 10, y: 10)
        )
        model.currentPointer = { CGPoint(x: 10, y: 10) }
        return model
    }

    @Test("a moved pointer lifts without selecting, a still one lifts none")
    func movementOnly() {
        let model = model()
        model.currentPointer = { CGPoint(x: 10, y: 30) }
        model.hoverRow(1, pointer: CGPoint(x: 10, y: 10))
        #expect(model.hover == nil)
        model.hoverRow(1, pointer: CGPoint(x: 10, y: 30))
        #expect(model.hover == .row(1))
        #expect(model.list.selection == 0)
        // The list re-ranks under the same pointer: no move, no lift.
        model.query = "i"
        #expect(model.list.results.count == 2)
        #expect(model.hover == nil)
        model.hoverRow(1, pointer: CGPoint(x: 10, y: 30))
        #expect(model.hover == nil)
        #expect(model.list.selection == 0)
    }

    /// The pointer moved where no row hears it — the field, the
    /// footer — then the list re-ranked under it: no lift.
    @Test("a re-rank under a pointer moved off the rows lifts nothing")
    func reRankAfterOffRowMove() {
        let model = model()
        var pointer = CGPoint(x: 10, y: 10)
        model.currentPointer = { pointer }
        pointer = CGPoint(x: 300, y: 5)
        model.query = "i"
        model.hoverRow(1, pointer: pointer)
        #expect(model.hover == nil)
        #expect(model.list.selection == 0)
    }

    @Test("a key clears the lift until the pointer moves again")
    func keyClearsLift() {
        let model = model()
        model.currentPointer = { CGPoint(x: 10, y: 30) }
        model.hoverRow(1, pointer: CGPoint(x: 10, y: 30))
        #expect(model.hover == .row(1))
        model.handle(.step(1), repeated: false)
        #expect(model.hover == nil)
        #expect(model.list.selection == 1)
        model.hoverRow(0, pointer: CGPoint(x: 10, y: 30))
        #expect(model.hover == nil)
        model.hoverRow(0, pointer: CGPoint(x: 10, y: 12))
        #expect(model.hover == .row(0))
        #expect(model.list.selection == 1)
    }

    /// The pointer rested off the rows — a header, the padding —
    /// then ↓ scrolled a row under it: no lift.
    @Test("a key scroll under a pointer resting off the rows lifts nothing")
    func keyScrollAfterOffRowRest() {
        let model = model()
        var pointer = CGPoint(x: 10, y: 10)
        model.currentPointer = { pointer }
        pointer = CGPoint(x: 10, y: 70)
        model.handle(.step(1), repeated: false)
        model.hoverRow(0, pointer: pointer)
        #expect(model.hover == nil)
    }

    /// A scroll slides another row under the still pointer: the lift
    /// leaves the row that moved away and lands on none.
    @Test("a scroll under a still pointer drops the lift")
    func scrollDropsLift() {
        let model = model()
        model.hoverRow(1, pointer: CGPoint(x: 10, y: 30))
        model.hoverRow(1, pointer: CGPoint(x: 10, y: 30))
        #expect(model.hover == .row(1))
        model.hoverRow(0, pointer: CGPoint(x: 10, y: 30))
        #expect(model.hover == nil)
    }

    @Test("leaving an item drops its lift and no other")
    func leaveDropsOwnLift() {
        let model = model()
        model.hoverRow(1, pointer: CGPoint(x: 10, y: 30))
        model.endHover(.row(0))
        #expect(model.hover == .row(1))
        model.endHover(.row(1))
        #expect(model.hover == nil)
    }

    @Test("an item hover lifts, never the selection or the current mark")
    func tileHover() {
        let model = model()
        model.loadView = { JumpScopeModelTests.viewList() }
        model.currentPointer = { CGPoint(x: 10, y: 10) }
        model.setScope(.view)
        let before = model.view?.selection
        model.hoverItem(.layout(.stack), pointer: CGPoint(x: 40, y: 10))
        #expect(model.hover == .item(.layout(.stack)))
        #expect(model.view?.selection == before)
        #expect(model.view?.layout?.live == .grid)
        model.hoverItem(.vision(lens: nil), pointer: CGPoint(x: 60, y: 30))
        #expect(model.hover == .item(.vision(lens: nil)))
        #expect(model.view?.selection == before)
        // A row hover reaches nothing while View shows.
        model.hoverRow(1, pointer: CGPoint(x: 50, y: 10))
        #expect(model.hover == .item(.vision(lens: nil)))
    }

    @Test("a side switch clears the lift")
    func scopeClearsLift() {
        let model = model()
        model.loadView = { JumpScopeModelTests.viewList() }
        model.hoverRow(1, pointer: CGPoint(x: 10, y: 30))
        model.setScope(.view)
        #expect(model.hover == nil)
    }

    @Test("a click selects the row, then picks it")
    func clickSelectsRow() {
        let model = model()
        var picked: [(JumpEntry, Bool)] = []
        model.onPick = { picked.append(($0, $1)) }
        model.clickRow(1, moveHere: true)
        #expect(model.list.selection == 1)
        #expect(picked.count == 1)
        #expect(picked.first?.0 == model.list.results[1].entry)
        #expect(picked.first?.1 == true)
    }

    @Test("a click selects the item, then applies it")
    func clickSelectsItem() throws {
        let model = model()
        model.loadView = { JumpScopeModelTests.viewList() }
        var applied: [ViewPickList.Pick] = []
        model.onApplyView = { applied.append($0) }
        model.setScope(.view)
        let item = try #require(
            model.view?.items(.layout).first { $0.pick == .layout(.stack) }
        )
        model.clickItem(item)
        #expect(model.view?.selected?.pick == .layout(.stack))
        #expect(applied == [.layout(.stack)])
    }

    /// ↩ cannot reach an item the query dims, so a click on one
    /// selects nothing and applies nothing.
    @Test("a click on a dimmed item does nothing")
    func dimmedClickIsInert() throws {
        let model = model()
        model.loadView = { JumpScopeModelTests.viewList() }
        var applied: [ViewPickList.Pick] = []
        model.onApplyView = { applied.append($0) }
        model.setScope(.view)
        model.query = "studio"
        let before = model.view?.selected?.pick
        let item = try #require(
            model.view?.items(.layout).first { $0.pick == .layout(.stack) }
        )
        model.clickItem(item)
        #expect(model.view?.selected?.pick == before)
        #expect(applied.isEmpty)
    }

    @Test("the selected item draws no lift; the accent wins")
    func selectedDrawsNoLift() {
        let hover = JumpHover.row(2)
        func lifts(_ row: Int, _ hover: JumpHover?, _ selected: Bool) -> Bool {
            JumpHover.lifts(
                .row(row),
                hover: hover,
                selected: selected,
                clickable: true
            )
        }
        #expect(lifts(2, hover, false))
        #expect(!lifts(2, hover, true))
        #expect(!lifts(1, hover, false))
        #expect(!lifts(1, nil, false))
    }

    /// The lift promises the click (owner ruling 2026-10-17): an
    /// item the query dims, or one that cannot apply, stays flat.
    @Test("an item a click leaves alone draws no lift")
    func inertDrawsNoLift() throws {
        #expect(
            !JumpHover.lifts(
                .row(2),
                hover: .row(2),
                selected: false,
                clickable: false
            )
        )
        let side = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Jump/JumpViewSide.swift"
                    ),
                encoding: .utf8
            )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(
            side.contains(
                "clickable:!list.isDimmed(line,index)&&item.isApplicable"
            )
        )
    }
}
