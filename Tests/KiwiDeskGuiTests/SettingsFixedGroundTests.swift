import Foundation
import Testing

@testable import KiwiDesk

/// The raw-colour lens's fixed-ground arm, split from
/// `SettingsRawColorTests` at the §2.1 ceiling.
///
/// Chrome that is dark in BOTH modes: the ambient-derived
/// hierarchical greys land near-white or near-black by the
/// WINDOW's appearance while the ground never moves, so on
/// these families they are banned outright — on mode-varying
/// surfaces they self-invert and gui.md's "prefer a concrete
/// ink" stays a preference. A CONTROL whose ink is picked from
/// the appearance is the same defect from the other side, and
/// the second arm here — picked by AppKit, or by a mode-varying
/// token the site names itself (#1198; `docs/ui-patterns.md`
/// carries the numbers).
///
/// Membership is STEM-derived, not a file list — the §2.1
/// ceiling keeps splitting exactly these families
/// (`HomeCardPlate+X`, `SettingsFooter+Y`), and a hand list let
/// the next split land outside the ban silently
/// (architect review 2026-08-10; the dark-pass branch split
/// `+SpacesTile` off and had to remember the entry).
///
/// **What the stem model deliberately does not reach**, so a
/// green here is not read as more than it is: a family qualifies
/// when its GROUND is fixed-dark, and a file that merely draws a
/// fixed-dark plate as one element on a mode-varying ground is
/// outside it — the tour's two `previewPlate` panels and
/// `BarsPanelPreview` are the shipped cases. Widening the stems
/// to reach them would ban an ambient ink across whole files
/// whose ground does move with the appearance, which the
/// argument above does not support. The ink those three put on
/// their plates is review's (gui.md states it as the obligation
/// it is).
@Suite("Settings fixed-ground inks")
struct SettingsFixedGroundTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// `ChromeScanRoots`, not `Settings` alone — the same root
    /// `SettingsThemeWiringTests` was moved onto in this change:
    /// the tour draws `previewPlate` too, so a Settings-only
    /// walk could not see a fixed-dark family landing there.
    private func chromeSources() throws -> [URL] {
        try ChromeScanRoots.sources(from: #filePath)
    }

    private let fixedGroundStems = [
        "SettingsFooter", "HomeCardPlate", "KeyboardBoard",
        "KeyboardChrome",
    ]

    @Test("no hierarchical grey on a fixed-dark ground")
    func fixedGroundsBanHierarchicalGreys() throws {
        let needles = [
            ".secondary", ".tertiary", ".quaternary",
        ]
        var matched: [String: Int] = [:]
        for (stem, name, source) in try fixedGroundSources() {
            matched[stem, default: 0] += 1
            for needle in needles {
                #expect(
                    !source.contains(needle),
                    Comment(
                        rawValue:
                            "\(name) draws \(needle) on "
                            + "fixed-dark chrome"
                    )
                )
            }
        }
        expectEveryStemMatched(matched)
    }

    /// The control-side arm of the same ban: a control's ink
    /// must be FIXED where the ground is, whoever picks it.
    ///
    /// Two ways to fail that, and the needles cover both.
    /// `.borderedProminent` lets AppKit pick, and it picks
    /// against the WINDOW's appearance. The neutralisations pick
    /// for themselves but pick `SettingsTheme.ink`, which is
    /// mode-VARYING and whose light value is byte-identical to
    /// `savePill` — 1.00:1 on the pill. Same collapse, opposite
    /// causes; `docs/ui-patterns.md` carries the measurements.
    ///
    /// What the `.plain` omission TRADES: `.plain` draws no ink,
    /// so it is legal here and the site's own `foregroundStyle`
    /// carries the obligation — which means a `.plain` control
    /// that states no ink inherits the ambient `.primary` and
    /// reproduces the collapse unseen by either arm. That one is
    /// review's, and gui.md states it as the obligation it is.
    @Test("no ambient-inked control on a fixed-dark ground")
    func fixedGroundsBanAmbientButtonInk() throws {
        let needles = [
            ".buttonStyle(.borderedProminent)",
            ".buttonStyle(.bordered)",
            ".settingsActionButton()",
            ".neutralButtonLabel()",
            ".neutralMenuLabel()",
        ]
        var matched: [String: Int] = [:]
        for (stem, name, source) in try fixedGroundSources() {
            matched[stem, default: 0] += 1
            for needle in needles {
                #expect(
                    !source.contains(needle),
                    Comment(
                        rawValue:
                            "\(name) draws \(needle), whose "
                            + "ink moves, on fixed-dark chrome"
                    )
                )
            }
        }
        expectEveryStemMatched(matched)
    }

    /// Every fixed-ground file as (stem, name, comment-stripped
    /// source) — one walk, so a family a split renames away
    /// disappears from BOTH arms at once rather than one.
    private func fixedGroundSources() throws
        -> [(String, String, String)]
    {
        var result: [(String, String, String)] = []
        for file in try chromeSources() {
            let name = file.lastPathComponent
            guard
                let stem = fixedGroundStems.first(where: {
                    name == "\($0).swift"
                        || name.hasPrefix("\($0)+")
                })
            else { continue }
            result.append(
                (
                    stem, name,
                    SourceScan.stripComments(
                        try String(contentsOf: file, encoding: .utf8)
                    )
                )
            )
        }
        return result
    }

    /// PER STEM, not an aggregate floor: a hand-restated total
    /// let a renamed-away one-file family hide behind another
    /// family's growth (re-review 2026-08-10, the
    /// rule-authoring "derive the number" clause).
    private func expectEveryStemMatched(
        _ matched: [String: Int]
    ) {
        for stem in fixedGroundStems {
            #expect(
                matched[stem, default: 0] >= 1,
                Comment(
                    rawValue:
                        "stem \(stem) matched no file — "
                        + "renamed family, update the stem"
                )
            )
        }
    }

}
