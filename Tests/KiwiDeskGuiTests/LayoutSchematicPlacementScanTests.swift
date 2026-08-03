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
            // Restates the number of relative cases rather than
            // deriving it — `SpawnPlacement` is not
            // `CaseIterable`, and this fails *shut*: a fifth
            // relative case reds here until someone looks. That
            // is the deliberate disposition, not an oversight
            // (`.claude/rules/rule-authoring.md`).
            #expect(hits.count == 2)
            for line in hits {
                #expect(line.contains(".tag(SpawnPlacement."))
            }
        }
        try schematicsConsumePlacementOnlyByPassingItOn(under: dir)
        // A scan that read nothing passes for having found no
        // violations — the file enumerator yields an empty
        // sequence for a missing directory rather than throwing,
        // so a rename would retire this guard in silence. The
        // floor is every tuned layout's schematic, and the
        // directory holds their editors and helpers besides.
        #expect(checked > LayoutMode.placementTabs.count)
        #expect(sawPicker)
    }

    /// Naming the two cases is only the *obvious* way to copy the
    /// rule. `placement.rawValue.hasPrefix("before")` under a
    /// `default:` arm is a complete copy that spells neither, and
    /// it walked past the needle above (guard-prover, 2026-08-03).
    ///
    /// So a schematic may not *consume* `placement` at all. The
    /// `allowed` list below is the one copy of which shapes may
    /// mention it — declaring it, animating on it, handing it to
    /// a child, and passing it to `SchematicPlacement.splice`.
    /// Anything else is a decision worth a reviewer, whatever it
    /// spells.
    private func schematicsConsumePlacementOnlyByPassingItOn(
        under dir: URL
    ) throws {
        let allowed = [
            "let placement: SpawnPlacement",
            ".animation(LayoutSchematic.damping, value: placement)",
            "value: placement",
            "placement,",
            "placement: placement",
            "placement: placement,",
        ]
        // `placement` as a whole word: not `placementTabs`, and
        // not the `"placement.…"` localization keys.
        let word = try NSRegularExpression(
            pattern: #"(?<![A-Za-z0-9_."])placement(?![A-Za-z0-9_])"#
        )
        var seen = 0
        for file in try SourceScan.swiftSources(under: dir)
        where file.lastPathComponent.hasSuffix("Schematic.swift") {
            seen += 1
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            for raw in source.split(separator: "\n") {
                let line = raw.trimmingCharacters(in: .whitespaces)
                let range = NSRange(
                    line.startIndex...,
                    in: line
                )
                guard
                    word.firstMatch(in: line, range: range) != nil
                else { continue }
                #expect(
                    allowed.contains(line),
                    Comment(
                        rawValue:
                            "\(file.lastPathComponent) reads "
                            + "`placement` as `\(line)` — a "
                            + "schematic may only declare it, "
                            + "animate on it, pass it on, or "
                            + "hand it to "
                            + "SchematicPlacement.splice"
                    )
                )
            }
        }
        #expect(seen == LayoutMode.placementTabs.count + 1)
    }
}
