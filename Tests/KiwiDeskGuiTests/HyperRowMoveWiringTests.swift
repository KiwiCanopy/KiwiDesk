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

    @Test("rows offer the move, and the caption names it, only with a key")
    @MainActor
    func offeredOnlyWithAKey() {
        #expect(HyperRowMoveActions.isOffered(key: .capsLock))
        #expect(!HyperRowMoveActions.isOffered(key: nil))
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
        // The key is read off the model, never a defaulted environment.
        #expect(
            row.contains(
                "HyperRowMoveActions.isOffered(key: model.appWide.hyperKey),"
            )
        )
        #expect(!row.contains("hyperKeyIsOff"))
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
        // One structure whether or not the row can move.
        #expect(
            menu.contains(
                "content.rowActions(offered: move != nil) { actions }"
            )
        )
        #expect(!menu.contains("} else {\n            content\n"))
        #expect(
            menu.contains("Button(HyperMoveWords.rowAction, action: onMove)")
        )
        #expect(menu.occurrences(of: ".disabled(true)") == 2)
        // The greyed copy is the taken arm's, never the live one's.
        #expect(
            menu.contains(
                "Button(HyperMoveWords.rowAction) {}\n"
                    + "                .disabled(true)"
            )
        )
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
        #expect(
            row.contains(
                "if HyperRowMoveActions.isOffered(key: model.appWide.hyperKey)"
                    + " {\n                caption(HyperKeyWords.rowMoveHint)"
            )
        )
        let sheet = try source("HyperMoveSheet.swift")
        #expect(
            sheet.contains(
                "if request.direction == .toHyper {\n"
                    + "                spoken(HyperMoveWords.sheetHint)"
            )
        )
    }

    @Test("the seam's offered flag gates every channel")
    func seamGatesEveryChannel() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent("Components/Common")
        let seam = SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(
                    "ContextShortcut.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(seam.contains(".contextMenu { if offered { menu() } }"))
        #expect(
            seam.contains(".accessibilityActions { if offered { menu() } }")
        )
        #expect(seam.contains("get: { offered && chordMenuShown },"))
    }
}
