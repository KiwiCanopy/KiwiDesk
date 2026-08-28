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
    /// Every directory that draws a schematic.
    ///
    /// The Onboarding tree joined in #678 Phase 4 pass 11, when
    /// the tour's spaces step began rendering the real
    /// `LayoutSchematicView` — a scan pointed only at the Settings
    /// components would not see a bespoke schematic written
    /// alongside it, which is precisely the "a schematic written
    /// tomorrow" case this suite exists for. A tree that imports
    /// the family joins this list in the same change.
    ///
    /// `Components/Profiles` joined in #859, when the preset
    /// preview sheet began mounting `LayoutSchematicView` — the
    /// same trigger, one tree over, and the obligation above
    /// discharged rather than reasoned about.
    ///
    /// **Stated limit on what a new root buys.** The sharper half
    /// of this suite — `schematicsConsumePlacementOnlyByPassingItOn`
    /// — filters on filenames containing "Schematic", and no file
    /// in `Components/Profiles` or `Onboarding` has one. So those
    /// roots get the two-case line scan and the root-coverage
    /// check, not the "may not consume a placement at all" rule: a
    /// copy spelled around the enum cases
    /// (`placement?.rawValue.hasSuffix("focused")`, the evasion
    /// found in 2026-08-03) passes there (guard-prover,
    /// 2026-08-17). It has always been true of `Onboarding`; it is
    /// newly worth writing down because the sheet is now the most
    /// likely place for someone to write such a copy.
    private static var roots: [URL] {
        let repo = SourceScan.repoRoot(from: #filePath)
        return [
            "Sources/KiwiDesk/Settings/Components/Layouts",
            "Sources/KiwiDesk/Settings/Components/Profiles",
            "Sources/KiwiDesk/Onboarding",
        ].map { repo.appendingPathComponent($0) }
    }

    /// `PlacementPicker` is the one file that may name a relative
    /// placement, and only to *offer* the choice — pinned to its
    /// `.tag` lines rather than exempted wholesale, since a
    /// file-level exemption would let a copy move in beside them.
    @Test("the placement rule lives in exactly one place")
    func theRuleIsNotCopied() throws {
        var checked = 0
        var sawPicker = false
        for file in try Self.roots.flatMap({
            try SourceScan.swiftSources(under: $0)
        }) {
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
            // Two shapes are admitted, and only two: the picker's
            // entries, and the spoken TITLE of the choice
            // (`placementTitle`, #812) — a label naming a case is
            // not the splice rule, and VoiceOver has no other way
            // to hear which entry is selected. Each is counted on
            // its own so the entries cannot be lost to the titles.
            let entries = hits.filter {
                $0.contains(".tag(SpawnPlacement.")
            }
            let titles = hits.filter {
                $0.trimmingCharacters(in: .whitespaces)
                    .hasPrefix("case .")
            }
            #expect(entries.count == 2)
            #expect(titles.count == 2)
            #expect(hits.count == entries.count + titles.count)
            #expect(source.contains("private var placementTitle"))
        }
        var seen = 0
        var read = 0
        for root in Self.roots {
            let counted =
                try schematicsConsumePlacementOnlyByPassingItOn(
                    under: root
                )
            seen += counted.seen
            read += counted.read
        }
        // Enumerating files proves nothing about having read
        // them: if `stripComments` or the needle stops matching,
        // zero lines are examined and the sweep passes for having
        // found no violations. Every placement-taking schematic
        // declares the value, so the floor is one line each.
        //
        // Counted over ALL roots rather than per root, since a
        // root may legitimately draw schematics without defining
        // any — which is what the Onboarding tree does.
        #expect(seen > LayoutMode.placementTabs.count)
        #expect(read >= placementTakingSchematics)
        // A scan that read nothing passes for having found no
        // violations — the file enumerator yields an empty
        // sequence for a missing directory rather than throwing,
        // so a rename would retire this guard in silence. The
        // floor is every tuned layout's schematic, and the
        // directory holds their editors and helpers besides.
        #expect(checked > LayoutMode.placementTabs.count)
        #expect(sawPicker)
        // Each root has to have been READ, or widening the list
        // buys nothing: one missing directory is invisible in the
        // total above, which the Layouts tree alone satisfies.
        for root in Self.roots {
            #expect(
                !(try SourceScan.swiftSources(under: root))
                    .isEmpty,
                Comment(
                    rawValue:
                        "\(root.lastPathComponent) yielded no "
                        + "Swift files — the scan root moved and "
                        + "this guard went quiet"
                )
            )
        }
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
    ) throws -> (seen: Int, read: Int) {
        let allowed = [
            "let placement: SpawnPlacement",
            ".animation(damping, value: placement)",
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
        return (seen, read)
    }

    /// BSP, Stack, Grid, Track and Scrolling take a placement;
    /// Monocle does not, so the `read` floor is one short of the
    /// tuned-layout count. Derived rather than typed out, so
    /// adding a tuned layout moves it.
    private var placementTakingSchematics: Int {
        LayoutMode.placementTabs.count - 1
    }
}
