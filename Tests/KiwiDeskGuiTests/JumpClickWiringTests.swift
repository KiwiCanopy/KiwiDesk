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
        // Nothing outside the model calls past them.
        let jump = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Jump")
        let files = try SourceScan.swiftSources(under: jump)
        #expect(files.count > 5)
        for file in files
        where !file.lastPathComponent.hasPrefix("JumpModel") {
            let source = try SourceScan.blankedSource(at: file)
                .split(whereSeparator: \.isWhitespace).joined()
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
                    + "selected:index==list.selection,clickable:true)"
            )
        )
        #expect(panel.contains("hover:model.hover,onApply:"))
        let side = try Self.squashed("JumpViewSide.swift")
        #expect(
            side.contains(
                "JumpHover.lifts(.item(item.pick),hover:hover,"
                    + "selected:isSelected(line,index),"
            )
        )
        #expect(
            side.occurrences(of: "isLifted:isLifted(item,") == 2
        )
    }

    /// Each view draws its lift on `isLifted` and nothing else.
    @Test("each view draws the lift on its flag")
    func viewsDrawTheLift() throws {
        for file in ["JumpRowView.swift", "JumpLayoutTile.swift"] {
            let source = try Self.squashed(file)
            let branch = source.range(of: "}elseifisLifted{")
            let fill = source.range(of: ".fill(paint.rowHover)")
            #expect(source.occurrences(of: "}elseifisLifted{") == 1)
            #expect(
                source.occurrences(of: ".fill(paint.rowHover)") == 1
            )
            #expect(
                (branch?.upperBound).map { b in
                    fill.map { $0.lowerBound > b } ?? false
                } ?? false,
                "\(file)"
            )
        }
        let chip = try Self.squashed("ViewChip.swift")
        #expect(
            chip.occurrences(
                of: ".fill(isLifted?paint.fill(paint.chipHover):"
            )
                == 1
        )
    }

    @Test("leaving an item reaches the model")
    func hoverEndIsWired() throws {
        for file in [
            "JumpRowView.swift", "JumpLayoutTile.swift", "ViewChip.swift",
        ] {
            let source = try Self.squashed(file)
            #expect(
                source.occurrences(
                    of: "ifcase.active=phase{onHover()}else{onHoverEnd()}"
                ) == 1,
                "\(file)"
            )
        }
        let panel = try Self.squashed("JumpPanelView.swift")
        #expect(panel.contains("onHoverEnd:{model.endHover(.row(index))}"))
        #expect(panel.contains("onHoverEnd:{model.endHover(.item($0))}"))
        let side = try Self.squashed("JumpViewSide.swift")
        #expect(
            side.occurrences(of: "onHoverEnd:{onHoverEnd(item.pick)}") == 2
        )
    }
}
