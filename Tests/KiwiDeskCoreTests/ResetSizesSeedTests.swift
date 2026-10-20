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
        DefaultKeybindings.bindings(
            spaces: [],
            resizeStep: 50,
            base: .standard
        )
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
            DefaultKeybindings.generationTopUp(
                existing: [],
                above: 4,
                base: .standard
            )
                == [row] + DefaultKeybindings.rows(ofGeneration: 6)
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
                above: 4,
                base: .standard
            ) == DefaultKeybindings.rows(ofGeneration: 6)
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

    /// The switch moves the reset with every other letter.
    @Test("the switch carries ⌃⌥R to ✦R")
    func movesWithTheLadder() {
        let row = DefaultKeybindings.resetSizesRow()
        #expect(ShortcutBase.hyper.rebased(row).combo == "hyper+r")
    }

    /// A 3.0.0 layer — the seed without the reset — on the Hyper
    /// base.
    private var movedLayer: [KeyBinding] {
        let reset = DefaultKeybindings.resetSizesRow().lua
        var config = GuiConfig()
        let index = config.layers.firstIndex { $0.isDefault } ?? 0
        config.layers[index].bindings = seeded.filter { $0.lua != reset }
        ShortcutBaseSwitch.apply(.hyper, to: &config)
        return config.layers[index].bindings
    }

    /// An install on the Hyper base gets the reset on ✦R beside
    /// its letters.
    @Test("the Hyper base gets ✦R")
    func movedLayerGetsHyper() {
        let layer = movedLayer
        #expect(layer.contains { $0.combo == "hyper+f" })
        let added = DefaultKeybindings.generationTopUp(
            existing: layer,
            above: 4,
            base: .hyper
        )
        #expect(added.map(\.combo) == ["hyper+r"])
    }

    /// ✦R registers as a bare R while Hyper is held, so a row
    /// already on bare R holds it, as it does in the move.
    @Test("a bare R holds ✦R")
    func bareRHoldsHyperR() {
        let mine = KeyBinding(
            combo: "r",
            lua: "KiwiDesk.open_settings()",
            kind: .navigation
        )
        #expect(
            DefaultKeybindings.generationTopUp(
                existing: movedLayer + [mine],
                above: 4,
                base: .hyper
            ).isEmpty
        )
    }

    /// The ⌃⌥ base gets ⌃⌥R, wherever the letters sit: the stored
    /// base decides, never a guess from the rows (#2460).
    @Test("the ⌃⌥ base gets ⌃⌥R")
    func unmovedLayerGetsTheSeed() {
        let reset = DefaultKeybindings.resetSizesRow()
        let added = DefaultKeybindings.generationTopUp(
            existing: seeded.filter { $0.lua != reset.lua },
            above: 4,
            base: .standard
        )
        #expect(added == [reset])
    }
}
