import Foundation
import Testing

@testable import KiwiDeskCore

/// ⌘⌘ opens the Desktop overview (#1229, owner 2026-11-01): a
/// double tap of either ⌘, the same key twice, seeded on the
/// "Show Desktop overview" row, reaching an existing install as
/// generation 13 and staying put on either shortcut base.
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

    @Test("the row taps either ⌘ twice and opens the Desktops side")
    func rowShape() throws {
        let combo = try #require(KeyCombo.parse(row.combo))
        #expect(combo == KeyCombo.tap(.command, side: nil, count: 2))
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
            ) == [row]
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
            ).isEmpty
        )
    }

    /// A ⌘⌘ the user already spent on something else stays theirs.
    @Test("a taken ⌘⌘ is not offered")
    func takenTapIsSkipped() {
        let mine = KeyBinding(
            combo: "cmd+cmd",
            lua: "KiwiDesk.toggle_floating()",
            kind: .navigation
        )
        #expect(
            DefaultKeybindings.generationTopUp(
                existing: [mine],
                above: 12,
                base: .standard
            ).isEmpty
        )
    }
}
