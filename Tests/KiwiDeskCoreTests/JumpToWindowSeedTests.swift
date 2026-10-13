import Foundation
import Testing

@testable import KiwiDeskCore

/// Jump to window's seed (#1875, keys ruled 2026-10-09, swept
/// 2026-10-11): `⌃⌥J` in the BASE seed, and in a generation of its
/// own so an existing install gets it once where free.
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

    /// An install already topped up to generation 2 from
    /// release/3.0.0 still gets the key.
    @Test("an install past generation 2 still gets ⌃⌥J")
    func joinsTheGeneration() {
        let row = DefaultKeybindings.jumpToWindowRow()
        #expect(DefaultKeybindings.rows(ofGeneration: 3) == [row])
        #expect(
            DefaultKeybindings.generationTopUp(existing: [], above: 2)
                == [row]
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
