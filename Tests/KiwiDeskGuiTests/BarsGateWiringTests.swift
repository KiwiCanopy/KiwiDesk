import Foundation
import KiwiDeskCore
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
            // An auto bar beside an always one is noted under each
            // row it can be set on (#761), over every screen's edges.
            "Components/Bars/KiwiShelfCard+Placement.swift": [
                "besideAlwaysNote(.space,in:[.monocle,.scrolling])",
                "besideAlwaysNote(.app,in:[.monocle])",
                "besideAlwaysNote(.app,in:[.scrolling])",
                "model.config.settings.screenVariants",
                // The Show drawer hangs under its master unruled.
                "SettingsCatalog.bars.kiwishelfShowEach,"
                    + "chrome:.attached,",
            ],
            // So does Position's (#761).
            "Components/Bars/KiwiShelfCard+Edge.swift": [
                "SettingsCatalog.bars.kiwishelfEdges,"
                    + "chrome:.attached,"
            ],
            // The one row gate the area answers (#2228): the Space
            // cue's Lua-owned grey — the whole constructor, since
            // `guiManaged` has a default a dropped argument would
            // fall back to — the grey it drives, and its sentence.
            "Components/Bars/KiwiShelfCard+SpaceCue.swift": [
                "BarsGates(settings:model.config.settings,"
                    + "guiManaged:model.guiManaged)"
                    + ".inertReason(for:.spaceBar(.spaceCue))",
                "disabled:reason!=nil",
                "BarsGateHelp.sentence(for:reason)",
            ],
            // The Reveal row's grey while no bar hides (owner
            // ruling, 2026-10-21), the grey it drives, and its
            // sentence.
            "Components/Bars/KiwiShelfCard+Reveal.swift": [
                ".inertReason(for:.kiwishelf(.revealStyle))",
                "GreyOut(active:reason!=nil)",
                "BarsGateHelp.sentence(for:reason)",
                ".inertReason(for:.colours(.animationsRevealDurationMS))",
                "GreyOut(active:revealInert)",
                ".inertReason(for:.colours(.animationsExpandDurationMS))",
                "GreyOut(active:reason==.expandOff)",
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
    /// describe one status two ways. The shelf's rows read the
    /// help for their own reasons; the two bar cards grey for no
    /// bar value (#761). (`BarColorCards` renders the block
    /// sentence from `ColorsAndGlassHelp` instead — it must name
    /// the OTHER page — so it is not a `BarsGateHelp` consumer.)
    @Test("gate sentences come only from BarsGateHelp")
    func gateSentencesLiveInTheHelpEnum() throws {
        for path in [
            "Components/Bars/KiwiShelfCard+Placement.swift",
            "Components/Bars/KiwiShelfCard+Rows.swift",
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
            "Components/Bars/KiwiShelfCard.swift",
            "Components/Bars/KiwiShelfCard+Placement.swift",
            "Components/Bars/KiwiShelfCard+Rows.swift",
            "Components/Colors/ColorsAndGlassRow+Bars.swift",
            "Components/Colors/BarColorCards.swift",
            "Components/Colors/RoleColorCards.swift",
        ]
        for key in [
            "kiwishelf.bars_split.help",
            "kiwishelf.background_fit.boxed_only",
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
            .boxedShelf, .barsSplit, .appWideLuaOwned,
        ]
        let sentences = all.map(BarsGateHelp.sentence)
        for sentence in sentences { #expect(!sentence.isEmpty) }
        #expect(Set(sentences).count == all.count)
    }

    /// Every runtime-gated bars row is answered by `BarsGates` or
    /// named as answered elsewhere, and the two sets are disjoint
    /// (gui.md, the census-gate convergence).
    @Test("every runtime-gated bars row is resolved")
    func runtimeGatesAreResolved() {
        let gated = Set(
            SettingKey.allCases.filter {
                $0.placement.area == .bars
                    && !($0.placement.gate?.runtimeConditions.isEmpty
                        ?? true)
            }
        )
        #expect(
            gated == BarsGates.resolved.union(BarsGates.resolvedElsewhere)
        )
        #expect(
            BarsGates.resolved
                .isDisjoint(with: BarsGates.resolvedElsewhere)
        )
    }

    /// The Reveal row greys while every bar reads Always, and
    /// stays live while one hides (owner ruling, 2026-10-21).
    @Test("the Reveal row greys while no bar hides")
    func revealGreysWhileNoBarHides() {
        var settings = TilingSettings()
        let key = SettingKey.kiwishelf(.revealStyle)
        settings.setEveryBarVisibility(.always)
        #expect(
            BarsGates(settings: settings).inertReason(for: key)
                == .noBarHides
        )
        settings.spaceBarStyle.visibility = .hidden
        #expect(BarsGates(settings: settings).inertReason(for: key) == nil)
    }

    /// The expand plays with every bar on Always, so its length
    /// greys only while its hidden switch is off (2026-10-21).
    @Test("the Expand duration greys only while the expand is off")
    func expandGreysOnlyWhenOff() {
        var settings = TilingSettings()
        let key = SettingKey.colours(.animationsExpandDurationMS)
        settings.setEveryBarVisibility(.always)
        #expect(BarsGates(settings: settings).inertReason(for: key) == nil)
        settings.animations.onExpand = false
        #expect(
            BarsGates(settings: settings).inertReason(for: key) == .expandOff
        )
    }

    /// The Space cue's switch greys under a Lua-owned config and
    /// stays live where the GUI owns it (#2228).
    @Test("the Space cue switch greys under Lua")
    func spaceCueGreysUnderLua() {
        let settings = TilingSettings()
        let key = SettingKey.spaceBar(.spaceCue)
        #expect(
            BarsGates(settings: settings, guiManaged: true)
                .inertReason(for: key) == nil
        )
        #expect(
            BarsGates(settings: settings, guiManaged: false)
                .inertReason(for: key) == .appWideLuaOwned
        )
    }
}
