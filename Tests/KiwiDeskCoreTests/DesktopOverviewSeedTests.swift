import Foundation
import Testing

@testable import KiwiDeskCore

/// ⌃⌥O opens the Desktop overview (#3167, replacing #1229's ⌘⌘): a
/// plain chord seeded on the "Show Desktop overview" row, reaching
/// an existing install as generation 13 and staying put on either
/// shortcut base.
@Suite("Desktop overview seed (#1229)")
struct DesktopOverviewSeedTests {
    private let row = DefaultKeybindings.desktopOverviewRow()

    private func seeded(_ base: ShortcutBase) -> [KeyBinding] {
        DefaultKeybindings.bindings(
            spaces: [],
            resizeStep: 50,
            base: base
        )
    }

    @Test("the row is ⌃⌥O, no tap, and opens the Desktops side")
    func rowShape() throws {
        let combo = try #require(KeyCombo.parse(row.combo))
        #expect(combo == KeyCombo.parse("ctrl+alt+o"))
        #expect(!combo.isTap)
        #expect(row.lua == KiwiHubSide.desktops.lua)
        #expect(row.label == "Show Desktop overview")
        #expect(row.kind == .navigation)
    }

    @Test("both bases seed the row unmoved")
    func seededOnEitherBase() {
        for base in ShortcutBase.allCases {
            #expect(seeded(base).filter { $0.lua == row.lua } == [row])
        }
    }

    @Test("generation 13 is the row alone")
    func joinsTheGeneration() {
        #expect(DefaultKeybindings.rows(ofGeneration: 13) == [row])
        #expect(DefaultKeybindings.newestGeneration >= 13)
        #expect(
            DefaultKeybindings.generationTopUp(
                existing: [],
                above: 12,
                base: .hyper
            ) == [row] + DefaultKeybindings.rows(ofGeneration: 14)
        )
    }

    /// A user who put the overview on a chord of their own keeps it.
    @Test("an overview bound elsewhere is not offered again")
    func boundOverviewIsSkipped() {
        let mine = KeyBinding(
            combo: "control+option+d",
            lua: KiwiHubSide.desktops.lua,
            kind: .navigation
        )
        #expect(
            DefaultKeybindings.generationTopUp(
                existing: [mine],
                above: 12,
                base: .standard
            ) == DefaultKeybindings.rows(ofGeneration: 14)
        )
    }

    /// A ⌃⌥O the user already spent on something else stays theirs.
    @Test("a taken ⌃⌥O is not offered")
    func takenChordIsSkipped() {
        let mine = KeyBinding(
            combo: "control+option+o",
            lua: "KiwiDesk.toggle_floating()",
            kind: .navigation
        )
        #expect(
            DefaultKeybindings.generationTopUp(
                existing: [mine],
                above: 12,
                base: .standard
            ) == DefaultKeybindings.rows(ofGeneration: 14)
        )
    }
}
