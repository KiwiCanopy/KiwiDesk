import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// KiwiHub's ⌥ (#2885 ▸ Ruling 6, 7): the Move here slot reads and
/// lights Swap here under ⌥ and ⇧⌥ alike, a refused selection
/// lights nothing, and the row ⌥ acts on draws the two-way route.
@MainActor
@Suite("KiwiHub Swap here footer and route")
struct JumpSwapFooterTests {
    private func lit(
        _ modifiers: NSEvent.ModifierFlags,
        swaps: Bool = true
    ) -> Int? {
        JumpFooter(
            scope: .windows,
            overflows: false,
            modifiers: modifiers,
            selectionSwaps: swaps
        ).leading
    }

    @Test("⌥ and ⇧⌥ light the Swap here slot")
    func footerLightsSwap() {
        #expect(lit(.option) == 1)
        #expect(lit([.shift, .option]) == 1)
        #expect(lit(.option, swaps: false) == nil)
        #expect(lit([.option, .command]) == nil)
        // Without ⌥ the refusal is not asked.
        #expect(lit(.shift, swaps: false) == 1)
    }

    @Test("⌥ rewrites the slot and leaves the digits unshifted")
    func footerWords() {
        LocalizationManager.shared.select("en")
        for held: NSEvent.ModifierFlags in [.option, [.shift, .option]] {
            let hints = JumpFooter(
                scope: .windows,
                overflows: false,
                modifiers: held
            ).hints
            #expect(hints[1] == "⌥↩ Swap here")
            #expect(hints[2] == "⌘1–9 Quick jump")
        }
    }

    @Test("the model's held modifiers carry ⌥")
    func modelCarriesOption() {
        let model = JumpModel(
            snapshot: JumpSnapshot(
                entries: [JumpListTests.row(1, "Safari")],
                here: "1",
                hereIcon: nil
            ),
            icons: [:],
            rowCap: 6,
            modifiers: [.shift, .option]
        )
        #expect(model.heldModifiers == [.shift, .option])
        model.noteModifiers([])
        #expect(model.heldModifiers.isEmpty)
    }

    @Test("⌥ draws the two-way route on its one row, never ⇧'s")
    func routeUnderOption() throws {
        let entry = JumpListTests.row(1, "Safari")
        let match = try #require(
            JumpSearch.matches([entry], query: "").first
        )
        let here = JumpRowText.Place(glyph: nil, text: "Space 2")
        func row(owns: Bool, shift: Bool, option: Bool) -> JumpRowView {
            JumpRowView(
                match: match,
                icon: nil,
                isSelected: owns,
                ownsShift: owns,
                ownsOption: owns,
                number: 1,
                commandHeld: false,
                shiftHeld: shift,
                optionHeld: option,
                wayHere: here,
                waySwap: here,
                onActivate: { _ in }
            )
        }
        let swap = row(owns: true, shift: true, option: true)
        #expect(swap.showsWaySwap && !swap.showsWayHere)
        #expect(!row(owns: false, shift: false, option: true).showsWaySwap)
        #expect(!row(owns: true, shift: true, option: false).showsWaySwap)
        LocalizationManager.shared.select("en")
        #expect(JumpRowText.waySwapFrame == "%1$@ ⇄ %2$@")
    }
}
