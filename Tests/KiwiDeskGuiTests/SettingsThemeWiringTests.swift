import Foundation
import Testing

@testable import KiwiDesk

/// The other half of the token guard: a token that resolves
/// correctly and that nothing draws is a resolver shipped dead
/// (the turn-14b lesson — a `guard-prover` run proves the TEST
/// reads a value, never that the RENDER does).
///
/// So every token declared by `SettingsTheme` must be either
/// **wired** — named against a file that actually renders it — or
/// **deferred**, with a reason and a standing check that it
/// appears nowhere at all. The two lists must together cover the
/// tokens the shipped source declares, which is read from that
/// source rather than restated here; a seventeenth token lands in
/// neither list and reds.
///
/// The needles are keyed on the USE site, not on the declaration
/// (`SettingsTheme.swift` is excluded from every scan): a needle
/// satisfied by the `static let` line would be satisfied by a
/// token nothing consumes, which is the exact defect.
@Suite("Settings theme wiring")
struct SettingsThemeWiringTests {
    /// Token → a file that must render it. One named site each,
    /// not an exhaustive map: the claim is "something draws
    /// this", and pinning every call site would make an ordinary
    /// restyle a test edit.
    private let wired: [String: String] = [
        "page": "SettingsView.swift",
        "card": "SettingsHeaderBar.swift",
        "sunken": "Chips.swift",
        "previewPlate": "HomeCardPlate.swift",
        "plateInk": "HomeCardPlate.swift",
        "hairline": "SettingsDetailPanel.swift",
        "ink": "SettingsHeaderBar.swift",
        "ink2": "SettingsHeaderBar+Status.swift",
        "ink3": "SidebarSearchField.swift",
        "groupHeading": "HomeScreen.swift",
        "accent": "SettingsView.swift",
        "warningSurface": "PermissionPausedBanner.swift",
        "warningInk": "SettingsHeaderBar.swift",
        "danger": "KeyRecorderRejectionRow.swift",
        "panel": "SettingsDetailPanel.swift",
        "savePill": "SettingsFooter.swift",
        "savePillInk": "SettingsFooter.swift",
    ]

    /// Token → why nothing draws it yet. Each ships with the
    /// table so the hex pins land once rather than a row per
    /// phase; moving one here to `wired` is what a consumer
    /// landing looks like.
    private let deferred: [String: String] = [
        "accentInk":
            "AppKit picks the label ink on a tinted prominent "
            + "button — the pill's Save included — so no site "
            + "draws it explicitly yet; the first custom "
            + "accent-filled control will",
        "onAccentKnob":
            "belongs to a knob on a LARGE accent field; the "
            + "shell shipped without one (the pill's controls "
            + "are buttons) — never a slider thumb, which "
            + "stays white in both appearances",
    ]

    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    private let declaration = "SettingsTheme.swift"

    @Test("every wired token is drawn by the file that claims it")
    func wiredTokensAreDrawn() throws {
        for (token, file) in wired {
            let source = try SourceScan.stripComments(
                String(
                    contentsOf: try site(named: file),
                    encoding: .utf8
                )
            )
            #expect(
                namesExactly(source, token),
                Comment(
                    rawValue:
                        "\(file) no longer draws "
                        + "SettingsTheme.\(token) — either it "
                        + "moved (repoint the needle at the new "
                        + "render site) or the token went dead."
                )
            )
        }
    }

    /// Identifier-boundary match, the metric suite's
    /// `namesExactly` adopted here after guard-prover
    /// (2026-08-10) proved the bare `contains` inert for
    /// `panel`: "SettingsTheme.panel" is a strict prefix of
    /// "SettingsTheme.panelWidth", which lives in the SAME
    /// claimed file — the first token/metric prefix pair to
    /// collide across the two declaration files. The name must
    /// be followed by something that cannot continue an
    /// identifier.
    private func namesExactly(
        _ source: String,
        _ token: String
    ) -> Bool {
        let needle = "SettingsTheme.\(token)"
        var rest = Substring(source)
        while let hit = rest.range(of: needle) {
            let after = rest[hit.upperBound...].first
            if after == nil
                || !(after!.isLetter
                    || after!.isNumber || after! == "_")
            {
                return true
            }
            rest = rest[hit.upperBound...]
        }
        return false
    }

    @Test("a deferred token really has no consumer")
    func deferredTokensAreUnused() throws {
        var drawn: [String] = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: settingsDir)
        where file.lastPathComponent != declaration {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            scanned += 1
            for token in deferred.keys
            where source.contains("SettingsTheme.\(token)") {
                drawn.append(
                    "\(token) in \(file.lastPathComponent)"
                )
            }
        }
        // The floor its siblings carry, and it needs it MORE than
        // they do: this test can only ever fail by finding
        // something, so reading nothing is indistinguishable from
        // passing. `FileManager.enumerator(at:)` returns a
        // non-nil enumerator for a missing directory and yields
        // nothing, so a moved or renamed `Settings/` makes
        // `swiftSources` return `[]` without throwing.
        #expect(scanned > 50)
        #expect(
            drawn.isEmpty,
            Comment(
                rawValue:
                    "now-consumed tokens still listed as "
                    + "deferred: " + drawn.joined(separator: ", ")
                    + " — move them to `wired` with their render "
                    + "site."
            )
        )
        for (token, reason) in deferred {
            #expect(!reason.isEmpty, Comment(rawValue: token))
        }
    }

    /// The completeness half, derived from production on one side
    /// and from the two lists on the other — a new token belongs
    /// to exactly one of them.
    @Test("the two lists cover every declared token")
    func listsCoverEveryToken() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: settingsDir.appendingPathComponent(
                    declaration
                ),
                encoding: .utf8
            )
        )
        var declared: Set<String> = []
        for line in source.split(separator: "\n") {
            guard
                let start = line.range(of: "static let "),
                let end = line.range(of: " = token(")
            else { continue }
            declared.insert(
                String(line[start.upperBound..<end.lowerBound])
            )
        }
        // A parse that found nothing would pass having read
        // nothing (#635).
        #expect(!declared.isEmpty)
        let listed = Set(wired.keys).union(deferred.keys)
        #expect(
            listed == declared,
            Comment(
                rawValue:
                    "unlisted: "
                    + declared.subtracting(listed).sorted()
                    .joined(separator: ", ")
                    + " · stale: "
                    + listed.subtracting(declared).sorted()
                    .joined(separator: ", ")
            )
        )
        #expect(
            Set(wired.keys).isDisjoint(with: deferred.keys)
        )
    }

    /// The retired system colours, and why each one is retired
    /// rather than merely discouraged.
    ///
    /// `Color.accentColor` is the sharp one: it reads the USER'S
    /// system accent and is **not** affected by `.tint`, so with
    /// the shell tinted kiwi every one of these rendered the
    /// window's own decoration in whatever hue the user had set —
    /// blue schematics in a green window. It looks like a synonym
    /// for the accent and is the opposite of one.
    ///
    /// The two `NSColor` surfaces are retired for the ordinary
    /// reason: they resolve against the SYSTEM window background,
    /// which this window no longer uses, so a card painted with
    /// `controlBackgroundColor` sits a few points off every card
    /// beside it and nothing says so.
    ///
    /// A LENS, not a list (the #520 rule): it scans for the shape
    /// across the whole tree, so a file added next year is covered
    /// by existing. There is no exemption map on purpose — if one
    /// of these ever has a legitimate home, that is a design
    /// argument to have, not an entry to add quietly.
    @Test("no retired system colour survives in the tree")
    func retiredSystemColorsAreGone() throws {
        // `.accentColor` with the LEADING DOT, not
        // `Color.accentColor`: a guard-prover run put
        // `hovering ? .accentColor : SettingsTheme.hairline` into
        // a Home card, where the type is inferred from the other
        // arm — the live defect, rendering the hover ring in the
        // user's system accent — and the spelled-out needle
        // passed green. Every escape hatch (`.foregroundColor(`,
        // `.tint(`, a ternary arm) is an inferred position, so the
        // dot form is the one that watches the COLOUR rather than
        // one way of writing it, and it subsumes the qualified
        // spelling. `SettingsTheme.accent` does not contain it.
        //
        // `controlAccentColor` is the same colour by another
        // route and would otherwise be uncovered.
        let retired = [
            ".accentColor",
            ".controlAccentColor",
            ".controlBackgroundColor",
            ".separatorColor",
        ]
        var offenders: [String] = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: settingsDir)
        where file.lastPathComponent != declaration {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            scanned += 1
            for needle in retired where source.contains(needle) {
                offenders.append(
                    "\(needle) in \(file.lastPathComponent)"
                )
            }
        }
        // A scan over no files would pass having read nothing
        // (#635).
        #expect(scanned > 50)
        #expect(
            offenders.isEmpty,
            Comment(
                rawValue:
                    "retired system colours: "
                    + offenders.joined(separator: ", ")
                    + " — these do not follow SettingsTheme "
                    + "(and Color.accentColor does not follow "
                    + "`.tint` either). Use the token."
            )
        )
    }

    /// A needle pointing at a file that no longer exists would
    /// throw rather than fail open, but the message is worth
    /// having.
    private func site(named file: String) throws -> URL {
        let match = try SourceScan.swiftSources(under: settingsDir)
            .first { $0.lastPathComponent == file }
        return try #require(
            match,
            Comment(rawValue: "no such render site: \(file)")
        )
    }
}
