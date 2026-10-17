import Foundation
import Testing

@testable import KiwiDesk

/// KiwiHub's views reach the model's click doors and hand the lift
/// the real selection (#2365): `JumpHoverTests` drives the model,
/// which stays green on a view calling past it.
@Suite("KiwiHub click wiring")
struct JumpClickWiringTests {
    private static func squashed(_ file: String) throws -> String {
        try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDesk/Jump/" + file)
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("a click takes the select-then-act doors")
    func clicksSelectFirst() throws {
        let panel = try Self.squashed("JumpPanelView.swift")
        #expect(
            panel.contains(
                "onActivate:{moveHereinmodel.clickRow(index,"
                    + "moveHere:moveHere)}"
            )
        )
        #expect(panel.contains("onApply:{model.clickItem($0)}"))
        // No view calls past them.
        for file in [
            "JumpPanelView.swift", "JumpViewSide.swift", "JumpRowView.swift",
            "ViewChip.swift", "JumpLayoutTile.swift",
        ] {
            let source = try Self.squashed(file)
            #expect(!source.contains("applyView("), "\(file)")
            #expect(!source.contains("onPick("), "\(file)")
        }
    }

    @Test("the lift is handed the item's real selection")
    func liftReadsTheSelection() throws {
        let panel = try Self.squashed("JumpPanelView.swift")
        #expect(
            panel.contains(
                "isLifted:JumpHover.lifts(.row(index),hover:model.hover,"
                    + "selected:index==list.selection)"
            )
        )
        let side = try Self.squashed("JumpViewSide.swift")
        #expect(side.occurrences(of: "selected:isSelected(line,index)") == 1)
        #expect(
            side.occurrences(of: "isLifted:isLifted(item.pick,") == 2
        )
    }
}
