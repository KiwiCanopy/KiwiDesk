import Foundation
import Testing

@testable import KiwiDesk

/// The accent must not land on TEXT.
///
/// A control style that colours its label from the tint renders
/// green words in this window, since #678 turn 16b tinted it
/// kiwi — so each such style owes a neutralising modifier and a
/// guard. This suite holds `.menuStyle(.borderlessButton)`
/// (found and fixed 2026-08-04) and enumerates the direct
/// `.neutralButtonLabel()` uses; the bordered half — sealed to
/// its neutralisation by `settingsActionButton()` since #771 —
/// is `SettingsBorderedSealTests`', split out of this file at
/// the 350-line ceiling.
///
/// **`.buttonStyle(.link)` reads the tint too and is left
/// accent on purpose** — a link that looks like a link is not
/// the defect this suite names, and its sites are text by
/// definition (`PaletteShelf`'s "Pair with Glow",
/// `KeyRecorderRejectionRow`'s "Steal" / "Go to"). Recorded
/// because an unlisted style reads as an unconsidered one, which
/// is exactly how the bordered half came to ship green.
///
/// **Two guarded is not a claim that only two styles exist.**
/// `.buttonStyle(.borderless)` takes its label colour the same
/// way and is NOT held as a pair, because `docs/ui-patterns.md`
/// declares that style icon-only and an icon has no label to
/// neutralise. The declaration is what makes the omission safe,
/// so it is the thing to re-check before trusting it — the one
/// site that paired the style with a TEXT label,
/// `SpacesSection+Overrides`' back breadcrumb, shipped green
/// under exactly that assumption and carries
/// `neutralButtonLabel()` now, pinned by
/// `directNeutralisationsAreEnumerated`. A second text-labelled
/// `.borderless` button means the declaration has stopped
/// holding, and this style earns a seal of its own.
///
/// A button with NO `.buttonStyle` renders bordered on macOS and
/// takes the tint while matching no needle here — that
/// convention (an action button names its style) is
/// `SettingsButtonStyleConventionTests`', whose arithmetic
/// counts `settingsActionButton()` as naming one.
@Suite("Settings label neutrality")
struct SettingsLabelNeutralityTests {
    /// The trees this guard covers.
    ///
    /// The Onboarding tree joined when #828 tinted it: the tour
    /// had no `.tint` at all, so every unstyled button there
    /// rendered a system-blue default and nothing was wrong with
    /// it. The moment the root took `SettingsTheme.accent` those
    /// same buttons started painting their labels from it, which
    /// is #759 arriving in the first window every user sees — so
    /// label neutrality follows the tint rather than the
    /// directory it was written for. `everyScanRootIsRead` is
    /// what keeps a renamed tree from retiring it in silence.
    private var scanRoots: [URL] {
        let repo = SourceScan.repoRoot(from: #filePath)
        return [
            "Sources/KiwiDesk/Settings",
            "Sources/KiwiDesk/Onboarding",
        ].map { repo.appendingPathComponent($0) }
    }

    /// Every Swift file under every scan root.
    private func scannedSources() throws -> [URL] {
        try scanRoots.flatMap {
            try SourceScan.swiftSources(under: $0)
        }
    }

    @Test("every scan root is actually read")
    func everyScanRootIsRead() throws {
        for root in scanRoots {
            #expect(
                !(try SourceScan.swiftSources(under: root))
                    .isEmpty,
                Comment(
                    rawValue: "\(root.lastPathComponent) yielded "
                        + "no Swift files — this guard no longer "
                        + "covers that tree"
                )
            )
        }
        // Derived from what the scan READ, never from the
        // literal list: deleting the Onboarding entry leaves the
        // loop above green, having faithfully checked whatever
        // roots remain.
        #expect(
            try scannedSources().contains {
                $0.path.contains("/Onboarding/")
            }
        )
    }

    /// Every borderless menu neutralises its label.
    ///
    /// The style paints its label in the accent, so with the
    /// window tinted kiwi each of these renders green text —
    /// several of them on the green-washed chips the same tint
    /// produces. Counted as a PAIR rather than allow-listed:
    /// there is no menu in this tree whose title should be the
    /// accent, because the accent marks control fills and these
    /// labels name a current value.
    ///
    /// Paired per FILE, not globally, so two menus in one file
    /// and none in another cannot cancel out.
    @Test("every borderless menu neutralises its label")
    func borderlessMenusAreNeutral() throws {
        var menus = 0
        for file in try scannedSources() {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let styled = source.occurrences(
                of: ".menuStyle(.borderlessButton)"
            )
            guard styled > 0 else { continue }
            menus += styled
            #expect(
                source.occurrences(of: ".neutralMenuLabel()")
                    == styled,
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) has \(styled) "
                        + "borderless menu(s) but not as many "
                        + "`.neutralMenuLabel()` — an accent-"
                        + "coloured menu title reads as an action "
                        + "and goes green-on-green on a chip."
                )
            )
        }
        // A scan that found no menus would pass having looked at
        // nothing (#635).
        #expect(menus > 0)
    }

    /// Direct `.neutralButtonLabel()` uses — on styles OTHER
    /// than `.bordered`, which since #771 only the seal may
    /// style. Each entry names the style the modifier must sit
    /// directly beneath, so the declaration cannot be satisfied
    /// by the modifier sitting on some other control in the same
    /// file — and a file not named here may not use the modifier
    /// at all.
    private let neutralisedDirectly:
        [String: (count: Int, style: String, why: String)] = [
            "SpacesSection+Overrides.swift": (
                1, ".buttonStyle(.borderless)",
                "the one text-labelled borderless breadcrumb "
                    + "docs/ui-patterns.md's icon-only "
                    + "declaration does not cover"
            )
        ]

    /// Every direct `.neutralButtonLabel()` is enumerated, on
    /// the style it declares.
    ///
    /// Both directions: a file named in `neutralisedDirectly`
    /// must still carry its neutralisation adjacent to the
    /// declared style (deleting the breadcrumb's ships an accent
    /// label), and a file NOT named there may not use the
    /// modifier directly at all — a bordered button reaching for
    /// it by hand belongs on the seal instead.
    @Test("direct neutralisations are enumerated")
    func directNeutralisationsAreEnumerated() throws {
        let sources = try scannedSources()
        // An entry for a file the scan cannot find is dead-green:
        // the loop below only visits files that exist, so a
        // renamed file would keep its declaration while the
        // breadcrumb it covers goes unwatched.
        for name in neutralisedDirectly.keys {
            _ = try #require(
                sources.first { $0.lastPathComponent == name },
                Comment(rawValue: "no such file: \(name)")
            )
        }
        for file in sources {
            let name = file.lastPathComponent
            // The definition and the seal are the mechanism, not
            // call sites; the seal's use is pinned by
            // `SettingsBorderedSealTests`.
            guard
                name != "SettingsActionButton.swift",
                name != "NeutralButtonLabel.swift"
            else { continue }
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let uses = source.occurrences(
                of: ".neutralButtonLabel()"
            )
            let declared = neutralisedDirectly[name]
            #expect(
                uses == (declared?.count ?? 0),
                Comment(
                    rawValue:
                        "\(name) has \(uses) direct "
                        + "`.neutralButtonLabel()` but declares "
                        + "\(declared?.count ?? 0) — a direct use "
                        + "is enumerated here with the style it "
                        + "sits on, or it goes through the seal."
                )
            )
            if let declared {
                #expect(
                    SourceScan.adjacentPairs(
                        in: source,
                        line: declared.style,
                        followedBy: ".neutralButtonLabel()"
                    ) == declared.count,
                    Comment(
                        rawValue:
                            "\(name) declares \(declared.count) "
                            + "neutralisation(s) on "
                            + "`\(declared.style)` "
                            + "(\(declared.why)), but not that "
                            + "many sit directly under that style "
                            + "— a declared use whose modifier "
                            + "moved elsewhere lets an accent "
                            + "label ship."
                    )
                )
            }
        }
    }
}
