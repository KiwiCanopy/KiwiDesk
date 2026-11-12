import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// KiwiHub's ⌥ (#2885 ▸ Ruling 6, 7; #3249): Swap here has its own
/// hint beside Move here and lights under ⌥ and ⇧⌥ alike, a
/// refused selection lights nothing, and the row ⌥ acts on draws
/// the two-way route.
@MainActor
@Suite("KiwiHub Swap here footer and route")
struct JumpSwapFooterTests {
    private func lit(
        _ modifiers: NSEvent.ModifierFlags,
        swaps: Bool = true
    ) -> Int? {
        JumpFooter(
            scope: .windows,
            modifiers: modifiers,
            selectionSwaps: swaps
        ).leading
    }

    @Test("⌥ and ⇧⌥ light the Swap here hint")
    func footerLightsSwap() {
        #expect(lit(.option) == 2)
        #expect(lit([.shift, .option]) == 2)
        #expect(lit(.option, swaps: false) == nil)
        #expect(lit([.option, .command]) == 3)
        // Without ⌥ the refusal is not asked.
        #expect(lit(.shift, swaps: false) == 1)
    }

    @Test("Move here and Swap here both show; ⌥ rewords the digits")
    func footerWords() {
        LocalizationManager.shared.select("en")
        for held: NSEvent.ModifierFlags in [
            [], .option, [.shift, .option],
        ] {
            let hints = JumpFooter(
                scope: .windows,
                modifiers: held
            ).hints
            #expect(hints[1] == "⇧↩ Move here")
            #expect(hints[2] == "⌥↩ Swap here")
        }
        let optioned = JumpFooter(scope: .windows, modifiers: .option)
        #expect(optioned.hints[3] == "⌥⌘1–9 Quick swap here")
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
                onActivate: { _ in },
                pickModifiers: { [] }
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
