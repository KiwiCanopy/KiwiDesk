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

    private func sizeRows() -> [KeyBinding] {
        seeded().filter { $0.lua.hasPrefix(resizePrefix) }
    }

    /// The map itself: which digit moves which axis, and which
    /// way. Within a pair the HIGHER digit grows — `2` over `1`
    /// for width, `5` over `4` for height.
    @Test("Each size row is ⌥⌘ + its own digit")
    func sizeRowsCarryTheirDigit() {
        let rows = seeded(step: 30)
        let expected = [
            ("option+command+1", #"KiwiDesk.resize("x", -30)"#),
            ("option+command+2", #"KiwiDesk.resize("x", 30)"#),
            ("option+command+4", #"KiwiDesk.resize("y", -30)"#),
            ("option+command+5", #"KiwiDesk.resize("y", 30)"#),
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
    ///
    /// The non-empty check is load-bearing rather than tidy: the
    /// loop below is skipped entirely when nothing is seeded on
    /// ⌥⌘, which is exactly the state after the regression this
    /// suite exists to catch, so without it the test would go
    /// green having looked at nothing.
    @Test("⌥⌘ carries size and nothing else")
    func sizeLayerCarriesOnlySize() throws {
        var onTheBase: [KeyBinding] = []
        for row in seeded() {
            let combo = try #require(KeyCombo.parse(row.combo))
            if combo.modifiers == sizeBase {
                onTheBase.append(row)
            }
        }
        #expect(!onTheBase.isEmpty, "nothing is seeded on ⌥⌘")
        for row in onTheBase {
            #expect(
                row.lua.hasPrefix(resizePrefix),
                "\(row.combo) is on ⌥⌘ but runs \(row.lua)"
            )
        }
    }

    /// The converse: every seeded size row is ON that base, so
    /// none is left behind on the positional ladder — and none is
    /// on an arrow, which is the point of the move. An arrow
    /// reads as a direction, and which edge of a tiled window is
    /// free depends on where it sits in the flat array.
    @Test("Every size row is on ⌥⌘, and none is an arrow")
    func everySizeRowIsOnTheSizeLayer() throws {
        let arrows = Set(
            ["left", "right", "up", "down"]
                .compactMap { KeyCombo.keyCodes[$0] }
        )
        #expect(arrows.count == 4, "arrow key names moved")
        let rows = sizeRows()
        #expect(rows.count == 4)
        for row in rows {
            let combo = try #require(KeyCombo.parse(row.combo))
            #expect(
                combo.modifiers == sizeBase,
                "\(row.combo) is a size row off the size layer"
            )
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

    /// "⌥⌘ is free" is a claim about macOS, not about the seed,
    /// and uniqueness *within* the seed cannot see it. An earlier
    /// draft of this layer put Grow height on `⌥⌘8`, which is
    /// macOS's Zoom toggle — `RegisterEventHotKey` refuses it and
    /// says nothing, so the row would simply never fire for a
    /// user with Zoom's keyboard shortcuts on. This holds every
    /// seeded row against the register of reserved chords, which
    /// now carries the ⌥⌘ family.
    @Test("No seeded row shadows a reserved macOS chord")
    func noSeededRowShadowsTheSystem() throws {
        #expect(
            !SystemShortcuts.map.isEmpty,
            "the reserved-chord register is empty"
        )
        for row in seeded() {
            let combo = try #require(KeyCombo.parse(row.combo))
            let reserved = SystemShortcuts.map[combo]
            #expect(
                reserved == nil,
                "\(row.combo) shadows \(reserved as Any)"
            )
        }
    }

    /// The specific collision that moved this layer off `7`/`8`,
    /// pinned so the register cannot quietly lose it and let a
    /// later retune walk back onto the same key.
    @Test("The ⌥⌘ Zoom chords are registered as reserved")
    func zoomChordsAreReserved() throws {
        for combo in [
            "option+command+8",
            "option+command+equal",
            "option+command+minus",
        ] {
            let parsed = try #require(KeyCombo.parse(combo))
            #expect(
                SystemShortcuts.map[parsed] != nil,
                "\(combo) is not registered as reserved"
            )
        }
    }
}
