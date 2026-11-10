import Foundation
import Testing

@testable import KiwiDeskCore

/// ⌥⇥ opens the window switcher on its last app (#3135, owner
/// 2026-11-09): seeded on the "Show window switcher for last app"
/// row, off the ⌃⌥ ladder by ruling so neither shortcut base moves
/// it, and reaching an existing install as generation 14.
@Suite("Window switcher last-app seed (#3135)")
struct WindowSwitcherLastAppSeedTests {
    private let row = DefaultKeybindings.windowSwitcherLastAppRow()

    private func seeded(_ base: ShortcutBase) -> [KeyBinding] {
        DefaultKeybindings.bindings(
            spaces: [],
            resizeStep: 50,
            base: base
        )
    }

    @Test("the row is ⌥⇥ running the last-app opener")
    func rowShape() throws {
        let combo = try #require(KeyCombo.parse(row.combo))
        #expect(combo == KeyCombo.parse("option+tab"))
        #expect(row.lua == KiwiHubSide.lastAppLua)
        #expect(row.label == "Show window switcher for last app")
        #expect(row.kind == .navigation)
        #expect(SystemShortcuts.map[combo] == nil)
    }

    @Test("both bases seed the row unmoved")
    func seededOnEitherBase() {
        for base in ShortcutBase.allCases {
            #expect(seeded(base).filter { $0.lua == row.lua } == [row])
        }
    }

    @Test("generation 14 is the row alone")
    func joinsTheGeneration() {
        #expect(DefaultKeybindings.rows(ofGeneration: 14) == [row])
        #expect(DefaultKeybindings.newestGeneration >= 14)
        #expect(
            DefaultKeybindings.generationTopUp(
                existing: [],
                above: 13,
                base: .hyper
            ) == [row]
        )
    }

    /// A user who put the opener on a chord of their own keeps it,
    /// and a ⌥⇥ already spent stays theirs.
    @Test("a bound opener or a taken ⌥⇥ is not offered")
    func userKeysStay() {
        let mine = KeyBinding(
            combo: "control+option+y",
            lua: KiwiHubSide.lastAppLua,
            kind: .navigation
        )
        let taken = KeyBinding(
            combo: "option+tab",
            lua: "KiwiDesk.toggle_floating()",
            kind: .navigation
        )
        for existing in [mine, taken] {
            #expect(
                DefaultKeybindings.generationTopUp(
                    existing: [existing],
                    above: 13,
                    base: .standard
                ).isEmpty
            )
        }
    }
}
