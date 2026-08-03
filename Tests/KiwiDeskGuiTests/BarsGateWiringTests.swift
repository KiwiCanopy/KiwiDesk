import Foundation
import Testing

@testable import KiwiDesk

/// The Bars and Advanced-Colours bar editors are wired to
/// `BarsGates` (#678 Phase 2; folded onto the reason-case shape
/// 2026-08-03), split from the behaviour coverage that lives in
/// `BarsCensusRenderTests` / `ColorsGateTests`.
///
/// General shipped a cut whose resolver was built only in tests
/// while the views re-derived each predicate — the census gate and
/// the on-screen grey could then drift with every gate test green.
/// This is the wiring half: EACH consumer's own container-gate
/// call, gate-granular, so a file resolving two containers reds if
/// EITHER goes hand-rolled (the file-granular hole guard-prover
/// caught in the Gaps lane).
@Suite("Bars gate wiring")
struct BarsGateWiringTests {
    private var dir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    private func read(_ path: String) throws -> String {
        try String(
            contentsOf: dir.appendingPathComponent(path),
            encoding: .utf8
        )
    }

    /// Whitespace-free source, so a needle survives the formatter
    /// wrapping a `containerReason(for:)` call across lines.
    private func squashed(_ path: String) throws -> String {
        SourceScan.stripComments(try read(path))
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    /// EACH bar block's own resolver call, not a file-level
    /// "touches the resolver somewhere". `BarColorCards` resolves
    /// BOTH bars, and a file check would stay green with one gone
    /// hand-rolled.
    @Test("each bar block gate is wired to the resolver")
    func blocksConsultTheResolver() throws {
        let consults: [String: [String]] = [
            "Components/Bars/AppBarCard.swift": [
                "gates.containerReason(for:.appBar)"
            ],
            "Components/Bars/SpaceBarCard.swift": [
                "gates.containerReason(for:.spaceBar)"
            ],
            "Components/Colors/BarColorCards.swift": [
                "gates.bars.containerReason(for:.spaceBar)",
                "gates.bars.containerReason(for:.appBar)",
            ],
        ]
        for (path, needles) in consults {
            let source = try squashed(path)
            for needle in needles {
                #expect(
                    source.contains(needle),
                    Comment(
                        rawValue:
                            "\(path) no longer wires `\(needle)` — "
                            + "that bar block gate went hand-rolled"
                    )
                )
            }
        }
    }

    /// Every gate sentence is authored ONCE, in `BarsGateHelp`; a
    /// row that re-authors one is the duplication that let General
    /// describe one status two ways. The two bar cards read the
    /// help for their block reason; the gap-indicator colour rows
    /// read it for theirs. (`BarColorCards` renders the block
    /// sentence from `AdvancedColorsHelp` instead — it must name
    /// the OTHER page — so it is not a `BarsGateHelp` consumer.)
    @Test("gate sentences come only from BarsGateHelp")
    func gateSentencesLiveInTheHelpEnum() throws {
        for path in [
            "Components/Bars/AppBarCard.swift",
            "Components/Bars/SpaceBarCard.swift",
            "Components/Colors/AdvancedColorRow+Bars.swift",
        ] {
            #expect(
                try squashed(path).contains("BarsGateHelp.sentence"),
                Comment(
                    rawValue:
                        "\(path) does not read BarsGateHelp.sentence "
                        + "for its inert caption"
                )
            )
        }
        let help = try read("Components/Bars/BarsGates.swift")
        let editors = [
            "Components/Bars/AppBarCard.swift",
            "Components/Bars/AppBarCard+Rows.swift",
            "Components/Bars/SpaceBarCard.swift",
            "Components/Colors/AdvancedColorRow+Bars.swift",
            "Components/Colors/BarColorCards.swift",
        ]
        for key in [
            "app_bar.no_layout.help",
            "space_bar.disabled.help",
            "app_bar.color.gap_only",
        ] {
            #expect(
                help.contains(key),
                Comment(rawValue: "BarsGateHelp lost \(key)")
            )
            for path in editors {
                #expect(
                    !(try read(path)).contains(key),
                    Comment(
                        rawValue:
                            "\(path) re-authors \(key) — it must "
                            + "come from BarsGateHelp"
                    )
                )
            }
        }
    }

    /// Every `BarsGates.InertReason` maps to its own non-empty
    /// sentence, so the grey and the words explaining it are one
    /// decision, never two that can disagree.
    @MainActor
    @Test("each reason has its own sentence")
    func eachReasonHasItsOwnSentence() {
        let all: [BarsGates.InertReason] = [
            .noBarShown, .spaceBarOff, .gapOnly,
        ]
        let sentences = all.map(BarsGateHelp.sentence)
        for sentence in sentences { #expect(!sentence.isEmpty) }
        #expect(Set(sentences).count == all.count)
    }
}
