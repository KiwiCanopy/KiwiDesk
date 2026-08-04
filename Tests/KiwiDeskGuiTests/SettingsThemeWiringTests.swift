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
        "hairline": "SettingsView.swift",
        "ink": "SettingsHeaderBar.swift",
        "ink2": "SettingsHeaderBar+Status.swift",
        "ink3": "SidebarSearchField.swift",
        "groupHeading": "HomeScreen.swift",
        "accent": "SettingsView.swift",
        "warningSurface": "PermissionPausedBanner.swift",
        "warningInk": "SettingsHeaderBar.swift",
        "danger": "KeyRecorderRejectionRow.swift",
        "onAccentKnob": "SettingsSlider.swift",
    ]

    /// Token → why nothing draws it yet. Each ships with the
    /// table so the hex pins land once rather than a row per
    /// phase; moving one here to `wired` is what a consumer
    /// landing looks like.
    private let deferred: [String: String] = [
        "panel":
            "the 392 pt preview column is Phase 4",
        "accentInk":
            "AppKit picks the label ink on a tinted prominent "
            + "button; the first site that draws it explicitly "
            + "is Phase 4's save pill",
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
                source.contains("SettingsTheme.\(token)"),
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

    @Test("a deferred token really has no consumer")
    func deferredTokensAreUnused() throws {
        var drawn: [String] = []
        for file in try SourceScan.swiftSources(under: settingsDir)
        where file.lastPathComponent != declaration {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            for token in deferred.keys
            where source.contains("SettingsTheme.\(token)") {
                drawn.append(
                    "\(token) in \(file.lastPathComponent)"
                )
            }
        }
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
        let retired = [
            "Color.accentColor",
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
