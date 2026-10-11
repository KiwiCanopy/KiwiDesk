import Foundation
import Testing

@testable import KiwiDeskCore

/// The layout cycle's seed (#453, keys ruled 2026-10-09): Next
/// layout on `⌃⌥C` in the BASE seed, Previous layout unbound.
/// Chord hygiene — parse, uniqueness, the system register — is
/// the generic nets' in `DefaultKeybindingsTests` and
/// `SizeLayerSeedTests`.
@Suite("Layout cycle seed (#453)")
struct LayoutCycleSeedTests {
    private var seeded: [KeyBinding] {
        DefaultKeybindings.bindings(spaces: [], resizeStep: 50)
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

    /// No `⇧` on a lettered row (#1094), so the back step
    /// has no seeded key at all.
    @Test("Previous layout ships unbound")
    func previousLayoutIsUnbound() {
        #expect(
            !seeded.contains { $0.lua.contains("cycle_mode(\"") }
        )
    }

    /// A layout verb, not app chrome: a GUI-created layer
    /// does not inherit it (the ruling's "base seed, not
    /// `appChromeRows`").
    @Test("Next layout is not app chrome")
    func nextLayoutIsNotChrome() {
        #expect(
            !DefaultKeybindings.appChromeRows().contains {
                $0.lua.hasPrefix("KiwiDesk.cycle_mode")
            }
        )
    }
}
