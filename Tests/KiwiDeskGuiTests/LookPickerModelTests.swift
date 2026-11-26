import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The look picker's keys (#3038 ▸ Ruling 2026-11-23): arrows move
/// the selection only, wrapping on a fresh press (#2897); ↩ wears a
/// look or closes on the worn one; Esc closes and never undoes; ⌘S
/// quick-saves the Current card alone and opens its name for a
/// rename (owner ruling Q5, ui-designer 2026-11-26).
@Suite("Look picker model (#3038)")
@MainActor
struct LookPickerModelTests {
    private func look(_ name: String) -> ShelfLook {
        ShelfLook(name: name, style: [:], colors: [:])
    }

    private func model(current: Bool = false, worn: Int? = 1)
        -> LookPickerModel
    {
        let entries = LookPickerEntry.cards(
            current: current ? look("") : nil,
            bundled: [look("A"), look("B")],
            saved: [look("Mine")]
        )
        return LookPickerModel(
            cards: entries,
            worn: current ? 0 : worn,
            settings: TilingSettings(),
            spaceLabels: []
        )
    }

    @Test("Current leads the cards and opens selected")
    func currentLeads() {
        let model = model(current: true)
        #expect(
            model.cards.map(\.kind) == [
                .current, .bundled, .bundled, .saved,
            ]
        )
        #expect(model.selection == 0)
        #expect(model.wornIndex == 0)
    }

    @Test("a fresh press wraps, a held key stops at the end")
    func arrowsWrapFresh() {
        let model = model(worn: 0)
        model.handle(.step(-1), repeated: true)
        #expect(model.selection == 0)
        model.handle(.step(-1), repeated: false)
        #expect(model.selection == 2)
        model.handle(.step(1), repeated: true)
        #expect(model.selection == 2)
        model.handle(.step(1), repeated: false)
        #expect(model.selection == 0)
    }

    @Test("only a step past the row's end reads as a wrap")
    func wrapIsMarked() {
        let model = model(worn: 0)
        // A held key stopped at the row's start moves and wraps nothing.
        model.handle(.step(-1), repeated: true)
        #expect(model.selection == 0 && !model.wrapped)
        model.handle(.step(1), repeated: false)
        #expect(model.selection == 1 && !model.wrapped)
        model.handle(.step(-1), repeated: false)
        model.handle(.step(-1), repeated: false)
        #expect(model.selection == 2 && model.wrapped)
        #expect(model.stepSide == -1)
        model.handle(.step(1), repeated: false)
        #expect(model.selection == 0 && model.wrapped)
        // A wrap rightward still steps rightward.
        #expect(model.stepSide == 1)
        model.select(2)
        #expect(!model.wrapped && model.stepSide == 1)
        model.select(1)
        #expect(model.stepSide == -1)
    }

    @Test("↩ wears another look once; on the worn look it closes")
    func enterWearsOrCloses() {
        let model = model(worn: 1)
        var worn: [String] = []
        var closed = 0
        model.onWear = { worn.append($0.look.name) }
        model.onClose = { closed += 1 }
        model.handle(.wear, repeated: false)
        #expect(closed == 1)
        #expect(worn.isEmpty)
        model.handle(.step(1), repeated: false)
        model.handle(.wear, repeated: false)
        model.handle(.wear, repeated: false)
        #expect(worn == ["Mine"])
        #expect(model.phase == .wearing)
    }

    @Test("Esc closes while a wear waits on the desk")
    func escapeDuringWear() {
        let model = model(worn: 1)
        var closed = 0
        model.onClose = { closed += 1 }
        model.handle(.step(1), repeated: false)
        model.handle(.wear, repeated: false)
        #expect(model.phase == .wearing)
        model.handle(.step(1), repeated: false)
        var saves = 0
        model.onQuickSave = {
            saves += 1
            return nil
        }
        model.handle(.save, repeated: false)
        #expect(saves == 0, "nothing but Esc acts during a wear")
        model.handle(.escape, repeated: false)
        #expect(closed == 1)
    }

    @Test("Esc closes and wears nothing")
    func escapeCloses() {
        let model = model()
        var closed = 0
        var worn = 0
        model.onClose = { closed += 1 }
        model.onWear = { _ in worn += 1 }
        model.handle(.escape, repeated: false)
        #expect(closed == 1)
        #expect(worn == 0)
    }

    @Test("⌘S saves only the Current card, then names it")
    func quickSaveOnCurrent() {
        let model = model(current: true)
        var beeps = 0
        model.onDeadKey = { beeps += 1 }
        model.onQuickSave = {
            ShelfLook(name: "Kiwi · Nov 24", style: [:], colors: [:])
        }
        model.handle(.step(1), repeated: false)
        model.handle(.save, repeated: false)
        #expect(beeps == 1)
        #expect(!model.isNaming)
        model.handle(.step(-1), repeated: false)
        model.handle(.save, repeated: false)
        #expect(model.cards[0].kind == .saved)
        #expect(model.cards[0].look.name == "Kiwi · Nov 24")
        #expect(model.nameDraft == "Kiwi · Nov 24")
    }

    @Test("a rename commits through the door; Esc keeps the quick name")
    func renameAfterSave() {
        let model = model(current: true)
        model.onQuickSave = {
            ShelfLook(name: "Kiwi · Nov 24", style: [:], colors: [:])
        }
        var renamed: [String] = []
        model.onRename = { _, to in
            renamed.append(to)
            return to
        }
        var closed = 0
        model.onClose = { closed += 1 }
        model.handle(.save, repeated: false)
        model.handle(.step(1), repeated: false)
        #expect(model.selection == 0, "arrows move the caret, not the card")
        model.handle(.escape, repeated: false)
        #expect(!model.isNaming)
        #expect(closed == 0, "the first Esc ends the rename only")
        #expect(model.cards[0].look.name == "Kiwi · Nov 24")
        model.nameDraft = "Night"
        model.handle(.commitName, repeated: false)
        #expect(renamed == ["Night"])
        #expect(model.cards[0].look.name == "Night")
        #expect(!model.isNaming)
    }

    @Test("a refused rename beeps and stays open")
    func refusedRename() {
        let model = model(current: true)
        model.onQuickSave = {
            ShelfLook(name: "Kiwi", style: [:], colors: [:])
        }
        model.onRename = { _, _ in nil }
        var beeps = 0
        model.onDeadKey = { beeps += 1 }
        model.handle(.save, repeated: false)
        model.nameDraft = "Glass"
        model.handle(.commitName, repeated: false)
        #expect(beeps == 1)
        #expect(model.isNaming)
    }
}
