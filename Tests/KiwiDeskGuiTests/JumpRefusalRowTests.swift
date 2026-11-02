import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A refused pick stays in KiwiHub (#2885 ▸ refusals shown in the
/// row): the row the held modifier speaks for shows ⛔ and why, a
/// refused press reaches no pick and is spoken, and the footer and
/// VoiceOver drop what would refuse.
@MainActor
@Suite("KiwiHub refusals shown in the row")
struct JumpRefusalRowTests {
    private func entry(
        swap: JumpSwapBlock? = nil,
        move: JumpMoveBlock? = nil
    ) -> JumpEntry {
        JumpEntry(
            target: .window(WindowID(1)),
            pid: 1,
            app: "Calculator",
            title: "",
            space: "2",
            spaceIcon: nil,
            status: .shown,
            movesHere: move == nil,
            swapBlock: swap,
            moveBlock: move
        )
    }

    private func model(_ entry: JumpEntry) -> JumpModel {
        JumpModel(
            snapshot: JumpSnapshot(entries: [entry], here: "1", hereIcon: nil),
            icons: [:],
            rowCap: 6
        )
    }

    @Test("a refused pick reaches no pick and is spoken")
    func refusedPressStays() {
        LocalizationManager.shared.select("en")
        let model = model(entry(swap: .floating, move: .fullScreen))
        var picked: [JumpPick] = []
        var spoken: [String] = []
        model.onPick = { picked.append($1) }
        model.onRefuse = { spoken.append($0) }
        model.handle(.swapHere, repeated: false)
        #expect(model.refusedRow == 0)
        model.clickRow(0, pick: .moveHere)
        model.handle(.quick(0, moveHere: true), repeated: false)
        #expect(picked.isEmpty)
        #expect(
            spoken == [
                "Can't swap: Floating",
                "Can't move here: Full Screen",
                "Can't move here: Full Screen",
            ]
        )
        // A jump is never refused here.
        model.handle(.pick(moveHere: false), repeated: false)
        #expect(picked == [.jump])
    }

    @Test("a pick the snapshot allows goes ahead")
    func allowedPressPicks() {
        let model = model(entry())
        var picked: [JumpPick] = []
        model.onPick = { picked.append($1) }
        model.onRefuse = { _ in Issue.record("refused") }
        model.handle(.swapHere, repeated: false)
        model.clickRow(0, pick: .moveHere)
        #expect(picked == [.swapHere, .moveHere])
        #expect(model.refusedRow == nil)
    }

    @Test("both families of reason are worded")
    func reasonsAreWorded() {
        LocalizationManager.shared.select("en")
        #expect(JumpRowText.refusal(JumpSwapBlock.floating) == "Floating")
        #expect(
            JumpRowText.refusal(JumpSwapBlock.yoursFloating)
                == "Yours is floating"
        )
        #expect(JumpRowText.refusal(.otherDesktop(2)) == "Desktop 2")
        #expect(JumpRowText.refusal(JumpMoveBlock.sticky) == "Sticky")
    }

    private func row(
        owns: Bool,
        shift: Bool = false,
        option: Bool = false,
        command: Bool = false,
        number: Int? = 1
    ) -> JumpRowView {
        let match = JumpSearch.matches([entry()], query: "")[0]
        return JumpRowView(
            match: match,
            icon: nil,
            isSelected: owns,
            ownsShift: owns,
            ownsOption: owns,
            number: number,
            commandHeld: command,
            shiftHeld: shift,
            optionHeld: option,
            wayHere: nil,
            refusal: JumpRowRefusal(swap: "Floating", move: "Sticky"),
            onActivate: { _ in }
        )
    }

    @Test("the reason shows on the row its modifier speaks for")
    func reasonFollowsTheModifier() {
        #expect(row(owns: true, option: true).shownRefusal == "Floating")
        #expect(
            row(owns: true, shift: true, option: true).shownRefusal
                == "Floating"
        )
        #expect(row(owns: true, shift: true).shownRefusal == "Sticky")
        #expect(row(owns: false, option: true).shownRefusal == nil)
        #expect(row(owns: false, shift: true).shownRefusal == nil)
        // ⇧⌘ reaches every numbered row, as its way here does.
        #expect(
            row(owns: false, shift: true, command: true).shownRefusal
                == "Sticky"
        )
        #expect(row(owns: true).shownRefusal == nil)
    }

    @Test("a refused selection lights nothing under ⇧")
    func footerUnderShift() {
        let footer = JumpFooter(
            scope: .windows,
            overflows: false,
            modifiers: .shift,
            selectionMoves: false
        )
        #expect(footer.leading == nil)
    }
}
