import Foundation
import Testing

@testable import KiwiDesk

/// A Maximize share pop-up offers ¼ ⅓ ½ ⅔ ¾ and Custom… (#3062,
/// owner 2026-11-08); a stored share outside them shows as one extra
/// checked item and goes once a fraction replaces it.
@Suite("Maximize share pop-up items (#3062)")
@MainActor
struct MaximizeShareMenuTests {
    @Test("A preset share adds no item and checks its fraction")
    func presetAddsNothing() {
        for share in FractionChips.shares {
            #expect(MaximizeShapeRow.offMenuShare(share.value) == nil)
            #expect(MaximizeShapeRow.selection(share.value) == share.value)
        }
        // Typed to the wire's precision, a third is still ⅓.
        #expect(MaximizeShapeRow.offMenuShare(0.3333) == nil)
        #expect(MaximizeShapeRow.selection(0.3333) == 1.0 / 3)
    }

    @Test("A share off the menu is its own checked item")
    func offMenuIsKept() {
        #expect(MaximizeShapeRow.offMenuShare(0.4) == 0.4)
        #expect(MaximizeShapeRow.selection(0.4) == 0.4)
    }

    /// A typed percent that rounds to a fraction stores the fraction
    /// itself, so the menu checks it (#3062, ruling amendment 2).
    @Test("Custom snaps a menu percent onto its fraction")
    func customSnaps() {
        for share in FractionChips.shares {
            let percent = MaximizeCustomShare.percent(of: share.value)
            #expect(
                MaximizeCustomShare.share(forPercent: percent)
                    == share.value
            )
        }
        #expect(MaximizeCustomShare.share(forPercent: 33) == 1.0 / 3)
        #expect(MaximizeCustomShare.share(forPercent: 40) == 0.4)
        #expect(MaximizeShapeRow.offMenuShare(0.4) == 0.4)
    }

    @Test("Custom clamps to the popover's range")
    func customClamps() {
        #expect(MaximizeCustomShare.share(forPercent: 5) == 0.1)
        #expect(MaximizeCustomShare.share(forPercent: 140) == 1)
        #expect(MaximizeCustomShare.tag < 0)
    }

    /// The share pop-up offers Custom… as its last item and opens the
    /// popover from that pick, anchored to itself.
    @Test("the share menu ends in Custom… and opens its popover")
    func menuWiresCustom() throws {
        let source = try shapeRowSource()
        #expect(
            source.contains(
                "Divider()Text(L(\"layout_defaults.maximize.custom\""
            )
        )
        #expect(source.contains("ifpicked==MaximizeCustomShare.tag{"))
        #expect(source.contains(".popover(item:customBinding(key))"))
    }

    /// A menu pop-up draws at its own width whatever frame it gets,
    /// so a fixed frame centres it and a column's pills start apart:
    /// every cell takes its natural width on the column's leading
    /// edge, as the From column does.
    @Test("every cell sits on its column's leading edge")
    func cellsLeadTheirColumn() throws {
        let source = try shapeRowSource()
        #expect(!source.contains(".frame(width:88)"))
        #expect(
            source.components(separatedBy: ".fixedSize()").count - 1 == 2
        )
        #expect(
            source.contains(
                "cell(key).frame(width:Self.columnWidth,alignment:.leading)"
            )
        )
    }

    private func shapeRowSource() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts/"
                    + "MaximizeShapeRow.swift"
            )
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
    }
}
