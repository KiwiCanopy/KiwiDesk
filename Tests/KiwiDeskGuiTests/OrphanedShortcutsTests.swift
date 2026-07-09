import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Orphan detection for the Inactive-shortcuts section (#92):
/// which bound rows target a space missing from the current
/// space list, and how they resurface as catalog commands.
@Suite("Orphaned space shortcuts (#92)")
@MainActor
struct OrphanedShortcutsTests {
    private let live = [SpaceID("1"), SpaceID("2")]

    private func navRow(_ lua: String) -> KeyBinding {
        KeyBinding(
            combo: "option+6",
            lua: lua,
            kind: .navigation,
            label: "row"
        )
    }

    @Test("a binding to a missing space is surfaced")
    func detectsOrphan() {
        let rows = [navRow("KiwiDesk.focus_space(\"6\")")]
        let commands = OrphanedShortcuts.commands(
            bindings: rows,
            spaces: live
        )
        #expect(commands.count == 1)
        #expect(
            commands.first?.lua
                == "KiwiDesk.focus_space(\"6\")"
        )
        #expect(commands.first?.label == "Go to Space 6")
    }

    @Test("all three space calls surface, in binding order")
    func allCallsSurface() {
        let rows = [
            navRow("KiwiDesk.move_to_space(\"6\")"),
            navRow(
                "KiwiDesk.move_to_space_and_follow(\"6\")"
            ),
            navRow("KiwiDesk.focus_space(\"7\")"),
        ]
        let commands = OrphanedShortcuts.commands(
            bindings: rows,
            spaces: live
        )
        #expect(commands.map(\.lua) == rows.map(\.lua))
        #expect(
            commands.map(\.label) == [
                "Move to Space 6",
                "Move to Space 6 & follow",
                "Go to Space 7",
            ]
        )
    }

    @Test("a binding to a live space is not an orphan")
    func liveSpaceExcluded() {
        let rows = [navRow("KiwiDesk.focus_space(\"2\")")]
        #expect(
            OrphanedShortcuts.commands(
                bindings: rows,
                spaces: live
            ).isEmpty
        )
    }

    @Test("custom rows stay in the Advanced drawer")
    func customExcluded() {
        var row = navRow("KiwiDesk.focus_space(\"6\")")
        row.kind = .custom
        #expect(
            OrphanedShortcuts.commands(
                bindings: [row],
                spaces: live
            ).isEmpty
        )
    }

    @Test("non-space navigation rows are not orphans")
    func directionalExcluded() {
        let rows = [
            navRow("KiwiDesk.focus(\"left\")"),
            navRow("KiwiDesk.resize(\"x\", 50)"),
            navRow("KiwiDesk.make_floating()"),
        ]
        #expect(
            OrphanedShortcuts.commands(
                bindings: rows,
                spaces: live
            ).isEmpty
        )
    }

    @Test("duplicate Lua rows surface once (row id is Lua)")
    func duplicatesDeduplicated() {
        let rows = [
            navRow("KiwiDesk.focus_space(\"6\")"),
            navRow("KiwiDesk.focus_space(\"6\")"),
        ]
        #expect(
            OrphanedShortcuts.commands(
                bindings: rows,
                spaces: live
            ).count == 1
        )
    }

    @Test("orphaned named space keeps catalog label + escape")
    func namedSpaceLabel() {
        let name = "old mail"
        let lua =
            "KiwiDesk.focus_space"
            + "(\(SpaceLuaArg.quote(name)))"
        let commands = OrphanedShortcuts.commands(
            bindings: [navRow(lua)],
            spaces: live
        )
        #expect(commands.first?.lua == lua)
        #expect(
            commands.first?.label == "Go to Space old mail"
        )
    }
}
