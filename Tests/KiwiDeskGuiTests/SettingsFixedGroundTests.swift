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
/// ink" stays a preference. A button STYLE that draws its own
/// label ink is the same defect from the control side, which
/// is the second arm here: AppKit re-picks a prominent
/// button's ink for an inactive window against that window's
/// appearance, and on a ground that does not move with it the
/// two disagree (#1198). Membership is STEM-derived, not a
/// file list — the §2.1 ceiling keeps splitting exactly these
/// families (`HomeCardPlate+X`, `SettingsFooter+Y`), and a
/// hand list let the next split land outside the ban silently
/// (architect review 2026-08-10; the dark-pass branch split
/// `+SpacesTile` off and had to remember the entry).
@Suite("Settings fixed-ground greys")
struct SettingsFixedGroundTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static var settingsDir: URL {
        root.appendingPathComponent("Sources/KiwiDesk/Settings")
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

    /// The control-side arm of the same ban.
    ///
    /// Every other control on the save pill is `.plain` over an
    /// explicit `savePillInk`, i.e. it owns its ink. A style
    /// that picks the ink itself picks it from the window, so
    /// on a fixed-dark ground the light appearance collapses
    /// the label into the plate — measured 1.23:1 enabled and
    /// 1.09:1 disabled before #1198, against 6.67:1 for
    /// `kiwiProminentButton()`, whose `accentInk` is the same
    /// in both appearances and every activation state.
    ///
    /// The needles are the spellings that carry an ink of their
    /// own; `.plain` is absent deliberately, because it draws
    /// none and inherits the site's `foregroundStyle`.
    @Test("no ink-picking button style on a fixed-dark ground")
    func fixedGroundsBanAmbientButtonInk() throws {
        let needles = [
            ".buttonStyle(.borderedProminent)",
            ".buttonStyle(.bordered)",
            ".settingsActionButton()",
        ]
        var matched: [String: Int] = [:]
        for (stem, name, source) in try fixedGroundSources() {
            matched[stem, default: 0] += 1
            for needle in needles {
                #expect(
                    !source.contains(needle),
                    Comment(
                        rawValue:
                            "\(name) lets \(needle) pick its "
                            + "label ink on fixed-dark chrome"
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
        for file in try swiftFiles(under: Self.settingsDir) {
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

    private func swiftFiles(under dir: URL) throws -> [URL] {
        var result: [URL] = []
        let walker = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: nil
        )
        while let next = walker?.nextObject() as? URL {
            if next.pathExtension == "swift" {
                result.append(next)
            }
        }
        return result
    }
}
