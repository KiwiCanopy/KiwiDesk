import Foundation
import Testing

@testable import KiwiDesk

/// The Gaps & Borders editors are wired to the gate resolver
/// (#678 Phase 3), split from the behaviour suite so neither file
/// crosses the size ceiling.
///
/// General shipped a round-1 cut whose resolver was built only in
/// tests while the views re-derived each predicate and re-authored
/// each sentence inline; the census gate and the on-screen grey
/// could then drift with every gate test still green. This is the
/// wiring half — the behaviour half is `GapsAndBordersGateTests`.
@Suite("Gaps & Borders gate wiring")
struct GapsAndBordersGateWiringTests {
    private var dir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/"
                    + "GapsAndBorders"
            )
    }

    private func read(_ name: String) throws -> String {
        try String(
            contentsOf: dir.appendingPathComponent(name),
            encoding: .utf8
        )
    }

    private func squashed(_ source: String) -> String {
        SourceScan.stripComments(source)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    /// EACH gate's own resolver call, not a file-level "touches
    /// the resolver somewhere". A file with two gates (Focus
    /// border's block + glow) would satisfy a file check while one
    /// gate quietly went hand-rolled — the very drift this guard
    /// exists to catch, and the hole the first cut of it left
    /// (caught by guard-prover before this PR). Sticky is
    /// deliberately ungated, so it is not a consumer.
    @Test("each gate is wired to the resolver, not a copy")
    func rowsConsultTheResolver() throws {
        let consults: [String: [String]] = [
            "GapsEditor.swift": [
                "gates.followersDiffer(for:.gaps(.outer))",
                "gates.followersDiffer(for:.gaps(.inner))",
            ],
            "FocusBorderEditor.swift": [
                "gates.containerReason(for:.focusBorder)",
                "gates.inertReason(for:.borders(.borderGlowSize))",
                "gates.inertReason("
                    + "for:.borders(.borderGlowSizeAuto))",
            ],
            "DragVisualsEditor.swift": [
                "gates.inertReason(for:.borders(.dragGhostBorder))",
                "gates.inertReason("
                    + "for:.borders(.dragDropZoneBorder))",
            ],
        ]
        for (name, needles) in consults {
            // Whitespace-free source, so a needle survives the
            // formatter wrapping a `gates.inertReason(for:)`
            // call across lines.
            let source = squashed(try read(name))
            for needle in needles {
                #expect(
                    source.contains(needle),
                    Comment(
                        rawValue:
                            "\(name) no longer wires `\(needle)` to "
                            + "the gate resolver — that gate went "
                            + "hand-rolled"
                    )
                )
            }
            // `.sentence(for:)` for a gate, or the named
            // acknowledgement a live master carries (#1383).
            #expect(
                source.contains("GapsBordersGateHelp."),
                Comment(
                    rawValue:
                        "\(name) does not read GapsBordersGateHelp "
                        + "for its caption"
                )
            )
        }
        // Every gate sentence is authored ONCE, in the help enum;
        // a row that re-authors one is the duplication that let
        // General describe one status two ways.
        let help = try read("GapsBordersGateHelp.swift")
        let allEditors =
            Array(consults.keys)
            + ["StickyMarkEditor.swift", "BordersCard.swift"]
        for key in [
            "border.controls.disabled",
            "border.glow_size.disabled",
            "drag.disabled.help",
            // Not InertReasons, same authoring rule: a master's
            // mixed-followers `?` is one sentence, in the help
            // enum, never re-typed beside the card.
            "border.shared.differ.help",
            "gaps.master.differ.help",
        ] {
            #expect(
                help.contains(key),
                Comment(rawValue: "GapsBordersGateHelp lost \(key)")
            )
            for name in allEditors {
                #expect(
                    !(try read(name)).contains(key),
                    Comment(
                        rawValue:
                            "\(name) re-authors \(key) — it must "
                            + "come from GapsBordersGateHelp"
                    )
                )
            }
        }
    }

    /// The two shared masters (#754), keyed on the sites that
    /// USE them rather than on the model properties that build
    /// them. A card reaching
    /// `$model.config.settings.borderStyle.width` directly, or
    /// `style.cornerStyle` for the picker, would set the ring
    /// alone — every stroke the card claims to drive would keep
    /// its old value, and no gate, census or parity guard above
    /// can see that (the Monitors lesson, gui.md).
    ///
    /// The `?` is the same shape of hole one level down: the
    /// mixed-strokes sentence SURFACES on a predicate, and a
    /// resolved answer nobody passes to a control leaves
    /// nothing behind for the resolver's own suite to find. So
    /// both halves are needled — the consult, and the `help:`
    /// argument that is the whole point of it.
    @Test("the shared masters are wired at their use sites")
    func mastersAreWiredWhereTheyAct() throws {
        let source = squashed(try read("BordersCard.swift"))
        for needle in [
            "value:model.borderWidthMaster,",
            "selection:model.borderCornersMaster,",
            "gates.followersDiffer("
                + "for:.borders(.borderWidthMaster))",
            "gates.followersDiffer("
                + "for:.borders(.borderCornerMaster))",
            "help:widthHelp",
            "help:cornersHelp",
        ] {
            #expect(
                source.contains(needle),
                Comment(
                    rawValue:
                        "BordersCard no longer uses `\(needle)` — "
                        + "the master writes one stroke and the "
                        + "other two silently keep their own, or "
                        + "it overwrites a disagreement in silence"
                )
            )
        }
    }

    /// The gap masters take the strokes' shape (#1383): LIVE while
    /// the edges differ, the acknowledgement on the label's `?`
    /// and nothing on the slider's `.disabled`. The resolver
    /// suite pins `followersDiffer`; this pins that its answer
    /// reaches the `?` and that no `.disabled(mixed)` came back —
    /// a greyed-but-draggable slider is the one shape worse than
    /// a wrong grey, and only the source shows it.
    @Test("the gap masters stay live and acknowledge at the label")
    func gapMastersAcknowledgeAtTheLabel() throws {
        let source = squashed(try read("GapsEditor.swift"))
        #expect(
            source.contains(
                "help:mixed?GapsBordersGateHelp.edgesDiffer:nil"
            ),
            Comment(
                rawValue:
                    "GapsEditor no longer hands the mixed-edges "
                    + "sentence to the label's `?`"
            )
        )
        #expect(
            !source.contains(".disabled("),
            Comment(
                rawValue:
                    "GapsEditor greys a master again — dimmed means "
                    + "no input on every channel (#1383)"
            )
        )
    }

    /// Each editor is MOUNTED, not merely declared. Every guard
    /// around one is satisfied by its own file existing: the
    /// catalog site scan finds each card's control referenced
    /// inside the very file that draws it, the census parity
    /// reads the order lists, and the area is bespoke so no
    /// render suite walks it. Delete one line in the section
    /// and that whole surface goes off screen with the rest of
    /// the suite green — which for `BordersCard` is the page's
    /// only width and corner control.
    @Test("every editor is mounted on the page")
    func theEditorsAreMounted() throws {
        let section = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/"
                    + "GapsAndBordersSection.swift"
            )
        let source = squashed(
            try String(contentsOf: section, encoding: .utf8)
        )
        for editor in [
            "GapsEditor",
            "BordersCard",
            "FocusBorderEditor",
            "DragVisualsEditor",
            "StickyMarkEditor",
        ] {
            #expect(
                source.contains("\(editor)(model:model)"),
                Comment(
                    rawValue:
                        "GapsAndBordersSection no longer mounts "
                        + "\(editor) — its whole card is off "
                        + "screen and nothing else can tell"
                )
            )
        }
    }
}
