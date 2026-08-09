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
    /// So a schematic may not *consume* the placement at all. The
    /// `allowed` list below is the one copy of which shapes may
    /// mention it — declaring it, animating on it, handing it to
    /// a child, and passing it to `SchematicPlacement.splice`.
    /// Anything else is a decision worth a reviewer, whatever it
    /// spells.
    ///
    /// Two evasions this had to be widened for, both proven
    /// against the first cut (guard-prover, 2026-08-03):
    ///
    /// - a helper taking the value under **another parameter
    ///   name** moved the whole rule out of an identifier scan's
    ///   sight, so the **type** is scanned alongside the name;
    /// - a copy in an **extension file** escaped a
    ///   `hasSuffix("Schematic.swift")` filter — and this lane's
    ///   own `TrackSchematic+Overflow.swift` proved that
    ///   schematic drawing code lives in such files — so the walk
    ///   matches `Schematic` anywhere in the stem.
    private func schematicsConsumePlacementOnlyByPassingItOn(
        under dir: URL
    ) throws {
        let allowed = [
            "let placement: SpawnPlacement",
            ".animation(LayoutSchematic.damping, value: placement)",
            "value: placement",
            "placement,",
        ]
        // Handing the value to a child: an argument whose value is
        // a plain name or dotted path. No call, no operator, so
        // `placement: rule(for: x)` is still a decision a reviewer
        // sees.
        let handOff = try NSRegularExpression(
            pattern: #"^placement: [A-Za-z0-9_.]+,?$"#
        )
        // The identifier as a whole word — not `placementTabs`,
        // not the `"placement.…"` localization keys — or the type
        // under any name at all.
        let needle = try NSRegularExpression(
            pattern: #"(?<![A-Za-z0-9_."])placement(?![A-Za-z0-9_])"#
                + #"|SpawnPlacement"#
        )
        var read = 0
        var seen = 0
        for file in try SourceScan.swiftSources(under: dir)
        where
            file.deletingPathExtension().lastPathComponent
            .contains("Schematic")
            && file.lastPathComponent != "SchematicPlacement.swift"
        {
            seen += 1
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            for raw in source.split(separator: "\n") {
                let line = raw.trimmingCharacters(in: .whitespaces)
                let range = NSRange(line.startIndex..., in: line)
                guard
                    needle.firstMatch(in: line, range: range) != nil
                else { continue }
                read += 1
                let passesItOn =
                    handOff.firstMatch(in: line, range: range)
                    != nil
                #expect(
                    allowed.contains(line) || passesItOn,
                    Comment(
                        rawValue:
                            "\(file.lastPathComponent) reads the "
                            + "placement as `\(line)` — a "
                            + "schematic may only declare it, "
                            + "animate on it, pass it on, or "
                            + "hand it to "
                            + "SchematicPlacement.splice"
                    )
                )
            }
        }
        // Enumerating files proves nothing about having read
        // them: if `stripComments` or the needle stops matching,
        // zero lines are examined and this passes for having
        // found no violations. Every placement-taking schematic
        // declares the value, so the floor is one line each.
        #expect(seen > LayoutMode.placementTabs.count)
        #expect(read >= placementTakingSchematics)
    }

    /// BSP, Stack, Grid, Track and Scrolling take a placement;
    /// Monocle does not, so the `read` floor is one short of the
    /// tuned-layout count. Derived rather than typed out, so
    /// adding a tuned layout moves it.
    private var placementTakingSchematics: Int {
        LayoutMode.placementTabs.count - 1
    }
}
