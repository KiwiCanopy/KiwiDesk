import Foundation
import Testing

@testable import KiwiDeskCore

/// The seeded ⌥⌘ **size** layer (#1075): size is not a
/// positional verb, so it takes a base of its own rather than a
/// rung on the ⌃⌥ ladder, and it binds digits rather than
/// arrows.
@Suite("The ⌥⌘ size layer (#1075)", .serialized)
struct SizeLayerSeedTests {
    private func seeded(step: Int = 50) -> [KeyBinding] {
        DefaultKeybindings.bindings(
            spaces: ["1", "2", "3"],
            resizeStep: step
        )
    }

    private var sizeBase: HotkeyModifiers { [.option, .command] }

    private var resizePrefix: String { "KiwiDesk.resize(" }

    /// The map itself: which digit moves which axis, and which
    /// way. Within a pair the HIGHER digit grows — `5` over `4`
    /// for width, `8` over `7` for height.
    @Test("Each size row is ⌥⌘ + its own digit")
    func sizeRowsCarryTheirDigit() {
        let rows = seeded(step: 30)
        let expected = [
            ("option+command+4", #"KiwiDesk.resize("x", -30)"#),
            ("option+command+5", #"KiwiDesk.resize("x", 30)"#),
            ("option+command+7", #"KiwiDesk.resize("y", -30)"#),
            ("option+command+8", #"KiwiDesk.resize("y", 30)"#),
        ]
        for (combo, lua) in expected {
            #expect(
                rows.contains { $0.combo == combo && $0.lua == lua },
                "\(combo) does not carry \(lua)"
            )
        }
    }

    /// ⌥⌘ is the SIZE base and carries nothing else. A positional
    /// verb seeded onto it would undo the one fact the layer
    /// exists to state, and would do it silently — every other
    /// suite here reads Lua and labels, not the base.
    @Test("⌥⌘ carries size and nothing else")
    func sizeLayerCarriesOnlySize() throws {
        for row in seeded() {
            let combo = try #require(KeyCombo.parse(row.combo))
            guard combo.modifiers == sizeBase else { continue }
            #expect(
                row.lua.hasPrefix(resizePrefix),
                "\(row.combo) is on ⌥⌘ but runs \(row.lua)"
            )
        }
    }

    /// And the converse: every seeded size row is ON that base,
    /// so none is left behind on the positional ladder.
    @Test("Every seeded size row is on ⌥⌘")
    func everySizeRowIsOnTheSizeLayer() throws {
        let sizeRows = seeded().filter {
            $0.lua.hasPrefix(resizePrefix)
        }
        #expect(sizeRows.count == 4)
        for row in sizeRows {
            let combo = try #require(KeyCombo.parse(row.combo))
            #expect(
                combo.modifiers == sizeBase,
                "\(row.combo) is a size row off the size layer"
            )
        }
    }

    /// Leaving the arrows is the point, not a side effect: an
    /// arrow reads as a direction, and which edge of a tiled
    /// window is free depends on where it sits in the flat array.
    @Test("No seeded size row is bound to an arrow")
    func noSizeRowUsesAnArrow() throws {
        let arrows = Set(
            ["left", "right", "up", "down"]
                .compactMap { KeyCombo.keyCodes[$0] }
        )
        #expect(arrows.count == 4)
        for row in seeded()
        where row.lua.hasPrefix(resizePrefix) {
            let combo = try #require(KeyCombo.parse(row.combo))
            #expect(
                !arrows.contains(combo.keyCode),
                "\(row.combo) still binds an arrow"
            )
        }
    }

    /// A new base is only free if nothing already seeded lands on
    /// it. Compares parsed combos, so an equivalent spelling
    /// counts as the same chord.
    @Test("No two seeded rows claim the same chord")
    func seededCombosStayUnique() throws {
        let rows = seeded()
        let combos = try rows.map {
            try #require(KeyCombo.parse($0.combo))
        }
        #expect(Set(combos).count == combos.count)
    }
}
