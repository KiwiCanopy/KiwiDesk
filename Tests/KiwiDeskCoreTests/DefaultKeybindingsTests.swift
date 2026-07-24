import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure starter-set builder (#91): combos must be valid and
/// collision-free, per-space rows position-based and capped,
/// and space names escaped through the one canonical quoter.
@Suite("Default starter shortcuts (#91)")
struct DefaultKeybindingsTests {
    private func spaces(_ count: Int) -> [SpaceID] {
        (1...count).map { SpaceID($0) }
    }

    @Test("every seeded combo parses as a valid KeyCombo")
    func combosParse() {
        let rows = DefaultKeybindings.bindings(
            spaces: spaces(9),
            resizeStep: 50
        )
        for row in rows {
            #expect(
                KeyCombo.parse(row.combo) != nil,
                "unparseable combo \(row.combo)"
            )
        }
    }

    @Test("no two seeded rows share a combo")
    func combosUnique() {
        let rows = DefaultKeybindings.bindings(
            spaces: spaces(9),
            resizeStep: 50
        )
        let combos = rows.map(\.combo)
        #expect(Set(combos).count == combos.count)
    }

    @Test("all rows are navigation kind with a label and lua")
    func rowShape() {
        let rows = DefaultKeybindings.bindings(
            spaces: spaces(3),
            resizeStep: 50
        )
        for row in rows {
            #expect(row.kind == .navigation)
            #expect(!row.label.isEmpty)
            #expect(row.lua.hasPrefix("KiwiDesk."))
        }
    }

    @Test("per-space rows cap at ten spaces, tenth on ⌃⌥0")
    func spacesCapped() {
        let rows = DefaultKeybindings.bindings(
            spaces: spaces(12),
            resizeStep: 50
        )
        let goTo = rows.filter {
            $0.lua.hasPrefix("KiwiDesk.focus_space(")
        }
        let move = rows.filter {
            $0.lua.hasPrefix("KiwiDesk.move_to_space(")
        }
        // Ten digit rows per tier — 1…9 then 0 for the tenth.
        #expect(goTo.count == 10)
        #expect(move.count == 10)
        #expect(
            rows.contains {
                $0.combo == "control+option+0"
                    && $0.lua == "KiwiDesk.focus_space(\"10\")"
            }
        )
        // No dead digit past ten (there is no eleventh key).
        #expect(
            !rows.contains { $0.combo == "control+option+10" }
        )
        #expect(
            !rows.contains { $0.combo == "control+option+11" }
        )
    }

    @Test("per-space combos are position-based, not name-based")
    func positionBasedCombos() {
        let named = [SpaceID("mail"), SpaceID("web")]
        let rows = DefaultKeybindings.bindings(
            spaces: named,
            resizeStep: 50
        )
        let mail = rows.first {
            $0.lua == "KiwiDesk.focus_space(\"mail\")"
        }
        let web = rows.first {
            $0.lua == "KiwiDesk.focus_space(\"web\")"
        }
        #expect(mail?.combo == "control+option+1")
        #expect(web?.combo == "control+option+2")
    }

    @Test("space names quote through the canonical escaper")
    func spaceNameEscaping() {
        let tricky = SpaceID("a\"b")
        let rows = DefaultKeybindings.bindings(
            spaces: [tricky],
            resizeStep: 50
        )
        let expected =
            "KiwiDesk.focus_space"
            + "(\(SpaceLuaArg.quote(tricky.raw)))"
        #expect(rows.contains { $0.lua == expected })
    }

    @Test("resize rows carry the configured step")
    func resizeStep() {
        let rows = DefaultKeybindings.bindings(
            spaces: [],
            resizeStep: 25
        )
        #expect(
            rows.contains {
                $0.lua == "KiwiDesk.resize(\"x\", -25)"
            }
        )
        #expect(
            rows.contains {
                $0.lua == "KiwiDesk.resize(\"x\", 25)"
            }
        )
    }

    @Test("no per-space rows when no space exists")
    func emptySpaces() {
        let rows = DefaultKeybindings.bindings(
            spaces: [],
            resizeStep: 50
        )
        #expect(
            !rows.contains {
                $0.lua.contains("_space")
            }
        )
        // The directional / resize / float set still seeds.
        #expect(!rows.isEmpty)
    }

    // MARK: - Additive digit top-up (#485)

    @Test("top-up binds only the digits grown past the seed")
    func topUpAddsOnlyNewDigits() {
        // Seeded for five spaces; the display change grew to ten.
        let existing = DefaultKeybindings.bindings(
            spaces: spaces(5),
            resizeStep: 50
        )
        let added = DefaultKeybindings.digitTopUp(
            existing: existing,
            spaces: spaces(10)
        )
        let combos = Set(added.map(\.combo))
        // ⌃⌥6-9 and ⌃⌥0 (tenth), across all three tiers — nothing
        // for the already-bound ⌃⌥1-5.
        #expect(!combos.contains("control+option+5"))
        #expect(combos.contains("control+option+6"))
        #expect(combos.contains("control+option+0"))
        #expect(combos.contains("control+option+shift+6"))
        #expect(combos.contains("control+option+command+0"))
        // Five new digits × three tiers.
        #expect(added.count == 15)
        #expect(
            added.contains {
                $0.combo == "control+option+0"
                    && $0.lua == "KiwiDesk.focus_space(\"10\")"
            }
        )
    }

    @Test("top-up never overwrites a user's custom chord")
    func topUpSkipsCustomChords() {
        // The user rebound ⌃⌥6 to something of their own.
        var existing = DefaultKeybindings.bindings(
            spaces: spaces(5),
            resizeStep: 50
        )
        existing.append(
            KeyBinding(
                combo: "control+option+6",
                lua: "KiwiDesk.toggle_floating()",
                kind: .custom,
                label: "Mine"
            )
        )
        let added = DefaultKeybindings.digitTopUp(
            existing: existing,
            spaces: spaces(10)
        )
        // Tier 1 for space 6 is taken, so it is not re-added; the
        // shift/command tiers for space 6 are still free.
        #expect(
            !added.contains { $0.combo == "control+option+6" }
        )
        #expect(
            added.contains {
                $0.combo == "control+option+shift+6"
            }
        )
    }

    @Test("top-up counts an equivalent alias as already bound")
    func topUpHonorsAliasedCombos() {
        // A hand-written config authored ⌃⌥7 as `ctrl+alt+7`.
        let existing = [
            KeyBinding(
                combo: "ctrl+alt+7",
                lua: "whatever()"
            )
        ]
        let added = DefaultKeybindings.digitTopUp(
            existing: existing,
            spaces: spaces(7)
        )
        // The alias parses to the same physical shortcut, so the
        // focus tier for space 7 is treated as taken.
        #expect(
            !added.contains { $0.combo == "control+option+7" }
        )
    }

    @Test("top-up respects the ten-space cap")
    func topUpCapsAtTen() {
        let added = DefaultKeybindings.digitTopUp(
            existing: [],
            spaces: spaces(12)
        )
        // Ten spaces × three tiers; nothing for spaces 11-12.
        #expect(added.count == 30)
        #expect(
            !added.contains { $0.lua.contains("(\"11\")") }
        )
    }

    @Test("top-up is a no-op when every digit is already bound")
    func topUpIdempotent() {
        let existing = DefaultKeybindings.bindings(
            spaces: spaces(5),
            resizeStep: 50
        )
        let added = DefaultKeybindings.digitTopUp(
            existing: existing,
            spaces: spaces(5)
        )
        #expect(added.isEmpty)
    }
}
