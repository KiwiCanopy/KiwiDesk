import Foundation
import Testing

@testable import KiwiDeskCore

/// Reset sizes in this Space's seed (#2303, narrowed by the owner
/// 2026-10-18): `⌃⌥R` runs `reset_layout_sizing` on the active
/// Space, reaches an existing install in generation 5, and moves
/// with the `⌃⌥` letters in the Hyper move. Chord hygiene is the
/// generic nets' in `DefaultKeybindingsTests`.
@Suite("Reset sizes seed (#2303)")
struct ResetSizesSeedTests {
    private var seeded: [KeyBinding] {
        DefaultKeybindings.bindings(spaces: [], resizeStep: 50)
    }

    @Test("⌃⌥R resets the active Space's sizes in the base seed")
    func seedsReset() {
        let row = DefaultKeybindings.resetSizesRow()
        #expect(row.combo == "control+option+r")
        #expect(row.lua == "KiwiDesk.reset_layout_sizing()")
        #expect(row.kind == .navigation)
        #expect(seeded.filter { $0.lua == row.lua } == [row])
    }

    /// An install already topped up to 3.0.0's generation gets
    /// the key, and nothing else, once.
    @Test("an install past generation 4 gets ⌃⌥R alone")
    func joinsTheGeneration() {
        let row = DefaultKeybindings.resetSizesRow()
        #expect(DefaultKeybindings.rows(ofGeneration: 5) == [row])
        #expect(
            DefaultKeybindings.generationTopUp(existing: [], above: 4)
                == [row]
        )
    }

    /// A user who already bound the reset keeps their chord.
    @Test("a reset bound elsewhere is not offered again")
    func boundResetIsSkipped() {
        let mine = KeyBinding(
            combo: "control+option+command+r",
            lua: "KiwiDesk.reset_layout_sizing()",
            kind: .navigation
        )
        #expect(
            DefaultKeybindings.generationTopUp(
                existing: [mine],
                above: 4
            ).isEmpty
        )
    }

    /// A Space verb, not app chrome: a GUI-created layer does not
    /// inherit it, as the layout keys do not.
    @Test("Reset sizes is not app chrome")
    func notChrome() {
        #expect(
            !DefaultKeybindings.appChromeRows().contains {
                $0.lua == DefaultKeybindings.resetSizesRow().lua
            }
        )
    }

    /// The Hyper move reads its list off the seed, so the reset
    /// moves to ✦R as one line of its own.
    @Test("the Hyper move carries ⌃⌥R to ✦R")
    func movesWithTheLadder() throws {
        let row = DefaultKeybindings.resetSizesRow()
        #expect(HyperShortcutMove.letterSeed.contains(row))
        let offer = HyperShortcutMove.offer(
            .toHyper,
            rows: seeded,
            base: .standard
        )
        let item = try #require(offer.items.first { $0.id == row.lua })
        #expect(item.seeds == [row])
        #expect(item.moves.map(\.to) == ["hyper+r"])
    }
}
