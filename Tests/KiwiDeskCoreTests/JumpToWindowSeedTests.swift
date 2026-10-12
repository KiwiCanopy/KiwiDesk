import Foundation
import Testing

@testable import KiwiDeskCore

/// Jump to window's seed (#1875, keys ruled 2026-10-09, swept
/// 2026-10-11): `⌃⌥J` in the BASE seed, and in 3.0.0's
/// generation so an existing install gets it once where free.
/// Chord hygiene is the generic nets' in `DefaultKeybindingsTests`.
@Suite("Jump to window seed (#1875)")
struct JumpToWindowSeedTests {
    private var seeded: [KeyBinding] {
        DefaultKeybindings.bindings(spaces: [], resizeStep: 50)
    }

    @Test("⌃⌥J opens Jump to window in the base seed")
    func seedsJump() {
        let row = DefaultKeybindings.jumpToWindowRow()
        #expect(row.combo == "control+option+j")
        #expect(row.lua == "KiwiDesk.show_jump_to_window()")
        #expect(row.kind == .navigation)
        #expect(
            seeded.filter { $0.lua == row.lua } == [row]
        )
    }

    @Test("an existing install gets ⌃⌥J with 3.0.0's generation")
    func joinsTheGeneration() {
        let row = DefaultKeybindings.jumpToWindowRow()
        #expect(
            DefaultKeybindings.rows(ofGeneration: 2).contains(row)
        )
        #expect(
            DefaultKeybindings.generationTopUp(existing: [], above: 1)
                .contains(row)
        )
    }

    /// A panel verb, not app chrome: a GUI-created layer does not
    /// inherit it, as the layout picker does not.
    @Test("Jump to window is not app chrome")
    func notChrome() {
        #expect(
            !DefaultKeybindings.appChromeRows().contains {
                $0.lua.hasPrefix("KiwiDesk.show_jump_to_window")
            }
        )
    }
}
