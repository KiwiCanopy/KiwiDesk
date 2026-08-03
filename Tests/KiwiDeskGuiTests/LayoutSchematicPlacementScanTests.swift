import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The forget-proof half of #702: nothing in the Layouts
/// components may branch on a relative placement again — the rule
/// is `Space.insert(_:placement:)`'s, reached through
/// `SchematicPlacement.splice`.
///
/// Split from `LayoutSchematicPlacementTests` because the two fail
/// apart, not merely for the line limit. That suite holds each
/// *existing* schematic to the promise its frame makes; no
/// assertion over existing types can see a schematic written
/// tomorrow that opens its window somewhere else. This one can,
/// and it is the only thing that can.
@Suite("Layout preview placement rule ownership")
struct LayoutSchematicPlacementScanTests {
    /// `PlacementPicker` is the one file that may name a relative
    /// placement, and only to *offer* the choice — pinned to its
    /// `.tag` lines rather than exempted wholesale, since a
    /// file-level exemption would let a copy move in beside them.
    @Test("the placement rule lives in exactly one place")
    func theRuleIsNotCopied() throws {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts"
            )
        var checked = 0
        var sawPicker = false
        for file in try SourceScan.swiftSources(under: dir) {
            let name = file.lastPathComponent
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            checked += 1
            let hits = source.split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .filter {
                $0.contains("beforeFocused")
                    || $0.contains("afterFocused")
            }
            guard name == "PlacementPicker.swift" else {
                #expect(
                    hits.isEmpty,
                    Comment(
                        rawValue:
                            "\(name) branches on a relative "
                            + "placement — ask "
                            + "SchematicPlacement.splice instead "
                            + "of copying Space.insert's rule"
                    )
                )
                continue
            }
            sawPicker = true
            #expect(hits.count == 2)
            for line in hits {
                #expect(line.contains(".tag(SpawnPlacement."))
            }
        }
        // A scan that read nothing passes for having found no
        // violations — the file enumerator yields an empty
        // sequence for a missing directory rather than throwing,
        // so a rename would retire this guard in silence. The
        // floor is every tuned layout's schematic, and the
        // directory holds their editors and helpers besides.
        #expect(checked > LayoutMode.placementTabs.count)
        #expect(sawPicker)
    }
}
