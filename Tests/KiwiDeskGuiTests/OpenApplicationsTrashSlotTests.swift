import Foundation
import Testing

/// The Open applications card's KiwiDesk rows hold the trash's
/// width, so their "Applies to" picker and key field line up with
/// the app rows above them, which end in a trash (owner
/// screenshot, 2026-10-11).
@Suite("Open applications trash slot")
struct OpenApplicationsTrashSlotTests {
    private func source(_ name: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings"
            )
            .appendingPathComponent(name)
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
    }

    private func squashed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("the card asks its KiwiDesk rows to hold the slot")
    func cardAsksForTheSlot() throws {
        let group = squashed(try source("KeybindingAppGroup.swift"))
        #expect(
            group.contains(
                "KiwiDeskKeyRows(model:model,bindings:$bindings,"
                    + "expander:expander)"
                    + ".environment(\\.keybindingReservesTrashSlot,true)"
            )
        )
    }

    /// The slot ends the row, after the key field, where the app
    /// row's trash stands.
    @Test("a row asked for the slot ends in it")
    func rowEndsInTheSlot() throws {
        let row = squashed(try source("KeybindingNavRow.swift"))
        let field = try #require(row.range(of: "KeyRecorderField("))
        let rest = row[field.upperBound...]
        let slot = try #require(
            rest.range(
                of: "onClear:clear)ifreservesTrashSlot{"
                    + "KeyReachTrashSlot()}}"
            )
        )
        #expect(slot.lowerBound > field.upperBound)
        #expect(
            row.contains(
                "@Environment(\\.keybindingReservesTrashSlot)"
                    + "privatevarreservesTrashSlot"
            )
        )
    }

    /// The slot is the trash's wider, shared-rule menu form,
    /// hidden — measured 25 pt against the plain button's 19 —
    /// and the trash itself stands in it, so either form a row
    /// draws keeps one column width.
    @Test("the slot is the menu trash, and the trash stands in it")
    func slotIsTheMenuTrash() throws {
        let column = squashed(try source("KeyReachColumn.swift"))
        let start = try #require(
            column.range(of: "structKeyReachTrashSlot:View{")
        )
        let end = try #require(
            column.range(
                of: "structKeyReachTrash:View{",
                range: start.upperBound..<column.endIndex
            )
        )
        let slot = column[start.upperBound..<end.lowerBound]
        #expect(
            slot.contains(
                "AppRuleDeleteButton(help:\"\",sharedFrom:Self.menuForm)"
                    + "{_in}.hidden().accessibilityHidden(true)"
            )
        )
        let trash = column[end.upperBound...]
        #expect(
            trash.contains(
                "varbody:someView{ZStack{KeyReachTrashSlot()"
                    + "AppRuleDeleteButton("
            )
        )
    }
}
