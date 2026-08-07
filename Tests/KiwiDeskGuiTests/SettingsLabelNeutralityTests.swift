import Foundation
import Testing

@testable import KiwiDesk

/// The accent must not land on TEXT.
///
/// A control style that colours its label from the tint renders
/// green words in this window, since #678 turn 16b tinted it
/// kiwi — so each such style owes a neutralising modifier and a
/// guard here. Two are held below:
/// `.menuStyle(.borderlessButton)`, found and fixed 2026-08-04,
/// and `.buttonStyle(.bordered)`, which shipped green until the
/// owner read "Add app rule", "Add application" and "Fit to
/// layout gaps" off the screen two days later.
///
/// **Two is not a claim that there are only two.**
/// `.buttonStyle(.borderless)` takes its label colour the same
/// way and is NOT held here: `docs/ui-patterns.md` declares that
/// style icon-only, which is why it was left, but
/// `SpacesSection+Overrides`' back breadcrumb pairs it with a
/// text `Label` — so the declaration is the thing to check
/// before adding a guard, not the style list.
///
/// That is why this is a suite rather than two loose tests: the
/// defect recurs per control style, and the next style that
/// paints a label from the tint belongs here beside them rather
/// than being found by eye a third time.
///
/// Both guards count per FILE, so two labels in one file and
/// none in another cannot cancel out.
///
/// **Stated residue: a button with NO `.buttonStyle` is not
/// covered.** macOS renders the default style as a bordered
/// push button, so it takes the tint exactly like an explicit
/// `.bordered` one — and the needle cannot see it. That is not
/// hypothetical: `PaletteShelf`'s "Import…" and
/// `ShortcutsHeader`'s "Import from init.lua…" were both still
/// reading green after the sweep this suite guards, and both
/// were found by eye rather than by any test.
///
/// It is left uncovered deliberately. A scan for an unstyled
/// `Button(` matches ~53 sites in this tree, and nearly all of
/// them are menu items, context-menu entries and alert buttons
/// whose labels are styled by their container — a guard over
/// that set would demand `.neutralButtonLabel()` at dozens of
/// call sites where it does nothing or is wrong, which is worse
/// than the gap. The mitigation is a convention instead: **give
/// an action button an explicit `.buttonStyle`**, which is what
/// brings it under the needle above.
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
            #expect(
                source.occurrences(of: ".neutralButtonLabel()")
                    == styled - exempt,
                Comment(
                    rawValue:
                        "\(name) has \(styled) bordered "
                        + "button(s) and \(exempt) exemption(s), "
                        + "so it needs \(styled - exempt) "
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
