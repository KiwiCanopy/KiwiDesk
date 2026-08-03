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

    /// EACH gate's own resolver call, not a file-level "touches
    /// the resolver somewhere". A file with two gates (Focus
    /// border's block + glow) would satisfy a file check while one
    /// gate quietly went hand-rolled — the very drift this guard
    /// exists to catch, and the hole the first cut of it left
    /// (caught by guard-prover before this PR). Sticky is
    /// deliberately ungated, so it is not a consumer.
    @Test("each gate is wired to the resolver, not a copy")
    func rowsConsultTheResolver() throws {
        // Whitespace-free source, so a needle survives the
        // formatter wrapping a `gates.inertReason(for:)` call
        // across lines.
        func squashed(_ name: String) throws -> String {
            SourceScan.stripComments(try read(name))
                .split(whereSeparator: \.isWhitespace)
                .joined()
        }
        let consults: [String: [String]] = [
            "GapsEditor.swift": [
                "gates.inertReason(for:.gaps(.outer))",
                "gates.inertReason(for:.gaps(.inner))",
            ],
            "FocusBorderEditor.swift": [
                "gates.containerReason(for:.focusBorder)",
                "gates.inertReason(for:.borders(.borderGlowSize))",
            ],
            "DragVisualsEditor.swift": [
                "gates.inertReason(for:.borders(.dragGhostBorder))",
                "gates.inertReason("
                    + "for:.borders(.dragGhostBorderWidth))",
                "gates.inertReason("
                    + "for:.borders(.dragDropZoneBorder))",
                "gates.inertReason("
                    + "for:.borders(.dragDropZoneBorderWidth))",
            ],
        ]
        for (name, needles) in consults {
            let source = try squashed(name)
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
            #expect(
                source.contains("GapsBordersGateHelp.sentence"),
                Comment(
                    rawValue:
                        "\(name) does not read GapsBordersGateHelp "
                        + "for its inert caption"
                )
            )
        }
        // Every gate sentence is authored ONCE, in the help enum;
        // a row that re-authors one is the duplication that let
        // General describe one status two ways.
        let help = try read("GapsBordersGateHelp.swift")
        let allEditors =
            Array(consults.keys) + ["StickyMarkEditor.swift"]
        for key in [
            "border.controls.disabled",
            "border.glow_size.disabled",
            "drag.disabled.help",
            "drag.border.off_help",
            "gaps.mixed.help",
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
}
