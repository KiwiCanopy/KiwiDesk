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

    @Test("per-space rows cap at nine spaces")
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
        #expect(goTo.count == 9)
        #expect(move.count == 9)
        #expect(
            !rows.contains { $0.combo == "control+option+10" }
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
}
