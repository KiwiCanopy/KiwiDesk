import Foundation
import Testing

@testable import KiwiDeskCore

/// The layout cycle's seed (#453, keys ruled 2026-10-09 and
/// 2026-10-11): Next layout on `⌃⌥C` and Previous layout on
/// `⌃⌥⇧C`, and the layout picker on `⌃⌥L` (#762), in the BASE
/// seed.
/// Chord hygiene — parse, uniqueness, the system register — is
/// the generic nets' in `DefaultKeybindingsTests` and
/// `SizeLayerSeedTests`.
@Suite("Layout cycle seed (#453)")
struct LayoutCycleSeedTests {
    private var seeded: [KeyBinding] {
        DefaultKeybindings.bindings(
            spaces: [],
            resizeStep: 50,
            base: .standard
        )
    }

    @Test("⌃⌥C runs Next layout in the base seed")
    func seedsNextLayout() {
        let row = DefaultKeybindings.nextLayoutRow()
        #expect(row.combo == "control+option+c")
        #expect(row.lua == "KiwiDesk.cycle_mode()")
        #expect(row.kind == .navigation)
        #expect(row.label == "Next layout")
        #expect(seeded.filter { $0 == row }.count == 1)
    }

    /// `⇧` reverses its twin (#1655, widened by #453); the
    /// ladder's senses are `DefaultKeybindingLadderTests`'.
    @Test("⌃⌥⇧C runs Previous layout in the base seed")
    func seedsPreviousLayout() {
        let row = DefaultKeybindings.previousLayoutRow()
        #expect(row.combo == "control+option+shift+c")
        #expect(row.lua == "KiwiDesk.cycle_mode(\"prev\")")
        #expect(row.label == "Previous layout")
        #expect(
            seeded.filter { $0.lua.contains("cycle_mode") } == [
                DefaultKeybindings.nextLayoutRow(),
                DefaultKeybindings.previousLayoutRow(),
            ]
        )
    }

    /// L for layout (#762, keys ruled 2026-10-09).
    @Test("⌃⌥L runs the layout picker in the base seed")
    func seedsLayoutPicker() {
        let row = DefaultKeybindings.layoutPickerRow()
        #expect(row.combo == "control+option+l")
        #expect(row.lua == "kiwihub.show(\"view\")")
        #expect(row.kind == .navigation)
        #expect(row.label == "Show view picker")
        #expect(seeded.filter { $0 == row }.count == 1)
    }

    /// A layout verb, not app chrome: a GUI-created layer
    /// does not inherit it (the ruling's "base seed, not
    /// `appChromeRows`").
    @Test("the layout cycle is not app chrome")
    func cycleIsNotChrome() {
        #expect(
            !DefaultKeybindings.appChromeRows().contains {
                $0.lua.hasPrefix("KiwiDesk.cycle_mode")
                    || $0.lua == KiwiHubSide.view.lua
            }
        )
    }
}
