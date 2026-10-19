import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A shortcut row's Move to Hyper (#2420): the row asks Core's one
/// verdict only while a key is set, stages through its own record,
/// re-judges at the click, and both hints are drawn where ruled.
@Suite("Hyper move: the row action's wiring")
struct HyperRowMoveWiringTests {
    private func source(_ path: String) throws -> String {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent("Components/Keybindings")
        return SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(path),
                encoding: .utf8
            )
        )
    }

    @Test("the caption points at the row action only while a key is set")
    @MainActor
    func captionHintNeedsAKey() {
        let offers = HyperKeyRow.offersRowMoveHint
        #expect(offers(.capsLock, false))
        #expect(!offers(nil, false))
        #expect(!offers(.capsLock, true))
    }

    @Test("the row consults Core while a key is set, and stages a record")
    func rowIsWired() throws {
        let row = try source("KeybindingNavRow.swift")
        #expect(
            row.contains(
                "HyperRowMoveActions(\n                move: hyperMove,"
            )
        )
        #expect(row.contains("onMove: moveToHyper"))
        #expect(
            row.contains(
                "guard !hyperKeyIsOff, let index else { return nil }"
            )
        )
        #expect(
            row.contains(
                "HyperShortcutMove.rowMove(bindings[index], in: bindings)"
            )
        )
        // The click re-judges and writes through the row's record.
        #expect(
            row.contains(
                "guard case .move(let to) = hyperMove else { return }\n"
                    + "        record(to)"
            )
        )
    }

    @Test("the menu offers the move, or greys it beside its holder")
    func menuIsWired() throws {
        let menu = try source("HyperRowMoveActions.swift")
        #expect(
            menu.contains("if let move {\n            content.rowActions {")
        )
        #expect(
            menu.contains("Button(HyperMoveWords.rowAction, action: onMove)")
        )
        #expect(menu.occurrences(of: ".disabled(true)") == 2)
        #expect(menu.contains("by: name(holder)"))
        #expect(
            menu.contains(
                ".accessibilityLabel(HyperMoveWords.spoken(text))"
            )
        )
    }

    @Test("both hints are drawn: the caption and the forward sheet")
    func hintsAreDrawn() throws {
        let row = try source("HyperKeyRow.swift")
        #expect(row.contains("caption(HyperKeyWords.rowMoveHint)"))
        let sheet = try source("HyperMoveSheet.swift")
        #expect(
            sheet.contains(
                "if request.direction == .toHyper {\n"
                    + "                spoken(HyperMoveWords.sheetHint)"
            )
        )
    }
}
