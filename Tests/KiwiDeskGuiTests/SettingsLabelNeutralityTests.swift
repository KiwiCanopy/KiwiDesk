import Foundation
import Testing

@testable import KiwiDesk

/// The accent must not land on TEXT.
///
/// A control style that colours its label from the tint renders
/// green words in this window, since #678 turn 16b tinted it
/// kiwi — so each such style owes a neutralising modifier and a
/// guard here. Held below:
/// `.menuStyle(.borderlessButton)`, found and fixed 2026-08-04,
/// and `.buttonStyle(.bordered)`, which shipped green until the
/// owner read "Add app rule", "Add application" and "Fit to
/// layout gaps" off the screen two days later.
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
/// way and is NOT held here, because `docs/ui-patterns.md`
/// declares that style icon-only and an icon has no label to
/// neutralise. The declaration is what makes the omission safe,
/// so it is the thing to re-check before trusting it — the one
/// site that paired the style with a TEXT label,
/// `SpacesSection+Overrides`' back breadcrumb, shipped green
/// under exactly that assumption and carries
/// `neutralButtonLabel()` now. A second text-labelled
/// `.borderless` button means the declaration has stopped
/// holding, and this style earns a guard of its own.
///
/// That is why this is a suite rather than two loose tests: the
/// defect recurs per control style, and the next style that
/// paints a label from the tint belongs here beside them rather
/// than being found by eye a third time.
///
/// Both guards count per FILE, so two labels in one file and
/// none in another cannot cancel out.
///
/// **A button with NO `.buttonStyle` is the hole these needles
/// cannot see**, and it is a real one, not a technicality: macOS
/// renders the default style as a bordered push button, so it
/// takes the tint exactly like an explicit `.bordered` one.
/// Eleven shipped green under a first cut of this suite that
/// called them acceptable residue — the two Imports, both Reset
/// actions, "Reveal", "Add", "Rename", "Open Login Items",
/// "Back to visual editor", "Use … as text", and "Enable
/// Accessibility…" green on the warning surface. All now name a
/// style, which is what brings them under the needles above.
///
/// The convention that keeps it closed — **an action button
/// names its style** — is still unguarded, and guarding the
/// neutralisation is the wrong shape for it: a scan for an
/// unstyled `Button(` matches ~53 sites here, nearly all menu
/// items, context-menu entries and alert buttons whose
/// containers style their labels, and demanding
/// `.neutralButtonLabel()` there would be wrong at most of them.
/// Guard the CONVENTION instead — an explicit `.buttonStyle` on
/// any `Button` not lexically inside a `Menu` / `contextMenu` /
/// `confirmationDialog` / `alert` closure — which asks nothing
/// of the menu sites. Tractable, and not yet built.
@Suite("Settings label neutrality")
struct SettingsLabelNeutralityTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
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
        for file in try SourceScan.swiftSources(under: settingsDir) {
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

    /// Files allowed to carry a bordered button WITHOUT
    /// `.neutralButtonLabel()`, and how many each may carry.
    ///
    /// **This map is the one copy of who may.** Three fields, and
    /// the middle one is what makes it more than a licence:
    ///
    /// - `count` — how many, so a file with one legitimate
    ///   exemption cannot quietly grow a second;
    /// - `needle` — the source token that IS the reason, which
    ///   must still appear at least `count` times. Without it the
    ///   guard pins only that the file still has *some* bordered
    ///   button, so swapping a destructive button for a plain one
    ///   keeps it green while an accent label ships — and in a
    ///   file with two bordered buttons it cannot even say which
    ///   one carries the modifier;
    /// - `why` — for the reader.
    private let borderedExempt:
        [String: (count: Int, needle: String, why: String)] = [
            "SpacesSection+Overrides.swift": (
                1, "role: .destructive",
                "the system red IS the warning and must survive"
            ),
            "SpaceOverrideRows+Footer.swift": (
                1, "role: .destructive", "reset-all"
            ),
            "NativeSpacesGroup.swift": (
                1, "role: .destructive",
                "unbind; its sibling bind button is neutralised"
            ),
            "KeyRecorderField.swift": (
                1, ".tint(buttonTint)",
                "resolves its own tint per state: red on a "
                    + "rejected chord, ink otherwise. The recording "
                    + "signal is the chrome's own accent fill, "
                    + "which never reads the tint"
            ),
        ]

    /// Neutralisations in a file that pair something OTHER than a
    /// bordered button, which the pairing count would otherwise
    /// read as a surplus.
    ///
    /// The modifier is not bordered-only — it fixes any label
    /// coloured from the tint — but this suite's arithmetic is,
    /// and a count cannot see WHICH control a modifier sits on.
    /// So a legitimate use on another style is declared here
    /// rather than allowed to inflate the pairing, which would
    /// hide a genuinely unneutralised bordered button in the same
    /// file.
    /// The declared style is asserted **adjacent** to the
    /// modifier, not merely present in the file. A bare count
    /// here is position-blind, and in a file that also holds an
    /// exemption the two cancel: `SpacesSection+Overrides` has
    /// one bordered button (destructive, exempt) and one
    /// `.borderless` breadcrumb, so `styled - exempt + other`
    /// stays at 1 if the single modifier is moved OFF the
    /// breadcrumb and ONTO the Delete — killing the system red
    /// the exemption exists to protect, while every count still
    /// balances. Adjacency is what says which control it sits on.
    private let neutralOnOtherStyles: [String: (count: Int, style: String)] = [
        "SpacesSection+Overrides.swift": (
            1, ".buttonStyle(.borderless)"
        )
    ]

    /// How many `.neutralButtonLabel()` sit directly beneath
    /// `style`, skipping blank lines. Line-wise rather than a
    /// regex, and local rather than a `SourceScan` primitive:
    /// `SourceScan` grows a helper when a SECOND guard needs the
    /// same walk, and this is the first.
    private static func adjacentNeutralisations(
        in source: String,
        under style: String
    ) -> Int {
        let lines = source.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ).map { $0.trimmingCharacters(in: .whitespaces) }
        var hits = 0
        for (i, line) in lines.enumerated() where line == style {
            var j = i + 1
            while j < lines.count, lines[j].isEmpty { j += 1 }
            if j < lines.count,
                lines[j] == ".neutralButtonLabel()"
            {
                hits += 1
            }
        }
        return hits
    }

    /// Every bordered button neutralises its label, or says why
    /// not.
    ///
    /// `.buttonStyle(.bordered)` paints its label from the tint,
    /// so with the window tinted kiwi each of these renders green
    /// text. Same defect as the borderless menus above and found
    /// the same way — by the owner reading "Add app rule",
    /// "Add application" and "Fit to layout gaps" off the screen
    /// in green — but this half was missed when the menu half was
    /// fixed.
    ///
    /// Allow-listed rather than counted as a bare pair, because
    /// unlike the menus there ARE bordered buttons whose label
    /// must not be ink: a destructive button's red is the
    /// warning. `.borderedProminent` needs no entry — it is a
    /// filled control, so its accent is the fill this rule
    /// protects, and it never matches this needle.
    @Test("every bordered button neutralises its label")
    func borderedButtonsAreNeutral() throws {
        var buttons = 0
        for file in try SourceScan.swiftSources(under: settingsDir) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let styled = source.occurrences(
                of: ".buttonStyle(.bordered)"
            )
            guard styled > 0 else { continue }
            buttons += styled
            let name = file.lastPathComponent
            let exempt = borderedExempt[name]?.count ?? 0
            let declared = neutralOnOtherStyles[name]
            let other = declared?.count ?? 0
            let owed = styled - exempt + other
            if let declared {
                // Adjacent, so the count cannot be satisfied by
                // the modifier sitting on some OTHER control in
                // the same file.
                let hits = Self.adjacentNeutralisations(
                    in: source,
                    under: declared.style
                )
                #expect(
                    hits == declared.count,
                    Comment(
                        rawValue:
                            "\(name) declares \(declared.count) "
                            + "neutralisation(s) on "
                            + "`\(declared.style)`, but "
                            + "\(hits) sit directly under that "
                            + "style — a declared offset whose "
                            + "modifier moved elsewhere lets an "
                            + "unneutralised label pass."
                    )
                )
            }
            #expect(
                source.occurrences(of: ".neutralButtonLabel()")
                    == owed,
                Comment(
                    rawValue:
                        "\(name) has \(styled) bordered "
                        + "button(s), \(exempt) exemption(s) and "
                        + "\(other) declared neutralisation(s) on "
                        + "another style, so it needs \(owed) "
                        + "`.neutralButtonLabel()` — an accent-"
                        + "coloured button title is text painted "
                        + "in a colour reserved for fills."
                )
            )
        }
        // A scan that found no buttons would pass having looked
        // at nothing (#635).
        #expect(buttons > 0)
    }

    /// An exemption for a file with no bordered button at all is
    /// a licence nothing needs — and it would silently absorb
    /// the first one added there.
    ///
    /// Checks the REASON too, not just the count: an exemption
    /// whose grounds have gone is the same licence, and it fails
    /// in the direction that ships an accent label.
    @Test("every bordered-button exemption is still used")
    func borderedExemptionsAreLive() throws {
        let sources = try SourceScan.swiftSources(under: settingsDir)
        for (name, entry) in borderedExempt {
            let file = try #require(
                sources.first { $0.lastPathComponent == name },
                Comment(rawValue: "no such file: \(name)")
            )
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            #expect(
                source.occurrences(of: entry.needle)
                    >= entry.count,
                Comment(
                    rawValue:
                        "\(name) is exempted for \(entry.count) "
                        + "bordered button(s) on the grounds "
                        + "`\(entry.needle)` (\(entry.why)), but "
                        + "that no longer appears \(entry.count) "
                        + "time(s) — the reason is gone, so the "
                        + "exemption goes with it."
                )
            )
            #expect(
                source.occurrences(of: ".buttonStyle(.bordered)")
                    >= entry.count,
                Comment(
                    rawValue:
                        "\(name) is exempted for "
                        + "\(entry.count) bordered button(s) "
                        + "(\(entry.why)) but no longer has that "
                        + "many — drop the entry."
                )
            )
        }
    }
}
