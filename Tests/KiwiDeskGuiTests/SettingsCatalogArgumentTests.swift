import Foundation
import Testing

@testable import KiwiDesk

/// The render-site half of the catalog guards (#277 part 2),
/// direction two: every `SettingsSection(` / `SettingsDisclosure(`
/// first argument is a catalog declaration. Direction one (every
/// declaration is rendered somewhere) is
/// `SettingsCatalogSiteTests`; the self-anchoring shape's
/// equivalent — one matching, non-literal id fed to both raw
/// halves — is `SettingsAnchorPrimitiveTests`.
@Suite("Settings catalog anchor arguments")
struct SettingsCatalogArgumentTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// Anchor-primitive sites whose first argument is a local
    /// variable the scan cannot resolve, each with the reason it
    /// is safe. Fail-shut: a new indirect site must be listed
    /// here consciously or the scan fails loud.
    private let indirectSites: Set<String> = [
        // Aliases of `SettingsCatalog.gapsAndBorders.gapsPerEdge` /
        // `.gapsPerAxis` — the same values, hoisted so the six
        // `GapRow`s can reach the children tersely.
        "GapsEditor.swift: perEdge",
        "GapsEditor.swift: perAxis",
        // The drag column helper takes its `SettingsControl` as
        // a parameter; both callers pass catalog declarations
        // (`dragGhost` / `dragDropZone`), which the dotted-
        // reference sweep still covers.
        "DragVisualsEditor.swift: control",
        // The self-anchoring control hands its descriptor to a
        // private row helper, so the argument at the
        // `.searchAnchored` site is the parameter, not a dotted
        // path. Covered by the dotted-reference sweep in
        // `SettingsCatalogSiteTests`; the count net above bites
        // future DIRECT mounts, which is where a duplicate id
        // would actually come from.
        "GapsEditor.swift: control",
        // The Desktop offer takes its drawer as a parameter so
        // one view can serve both shortcut groups (#1125); the
        // two mounts pass `focusDesktops` / `moveWindowsDesktops`
        // as dotted catalog references, which the sweep in
        // `SettingsCatalogSiteTests` still covers. They never
        // co-render — each group mounts its own.
        "DesktopShortcutsOffer.swift: drawer",
    ]

    /// Sanctioned literal-`L()` `SettingsSection` titles —
    /// currently none: the last one (the per-layout `"%1$@
    /// bar"` heading) died with the per-layout bar override
    /// GUI (GUI_REMOVED_2026-08). The set stays, fail-shut,
    /// for the next computed heading.
    private let literalTitleSites: Set<String> = []

    /// Direct catalog references legitimately mounted at two
    /// sites. **Mutual exclusion is the only admissible
    /// reason** — the sites must never co-render, or the shared
    /// id is ambiguous.
    /// Empty since #678 turn 13b, and kept so the next mutually
    /// exclusive pair has to be recorded on purpose rather than
    /// pass as an ordinary double mount.
    ///
    /// Monitors' entry left it: the picture and the
    /// "not connected" banner used to be if/else TWINS each
    /// mounting `monitors.spacePlacement`, and they are now two
    /// gated ROWS inside one mount of it — which is what the
    /// census says they are. (The bar colour drawers left this
    /// list earlier, when the Bars switch died: they co-render
    /// now, so each mounts its own instance declaration.)
    private let alternatelyMounted: [String: Int] = [:]

    /// Every `SettingsSection(` / `SettingsDisclosure(` first
    /// argument is a catalog declaration (counted, so a
    /// co-mounted double reference trips), an allow-listed
    /// indirect parameter, or the one sanctioned computed title.
    /// A literal `L()` header fails: declaring it in the catalog
    /// is what makes it findable.
    @Test("anchor primitives take catalog declarations")
    func anchorPrimitivesTakeCatalogDeclarations() throws {
        var direct: [String: Int] = [:]
        var modeTabs: [String] = []
        var problems: [String] = []

        for file in try SourceScan.swiftSources(under: settingsDir)
        where !SourceScan.isCatalogFile(
            file.lastPathComponent
        ) {
            let name = file.lastPathComponent
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            for needle in [
                "SettingsSection(", "SettingsDisclosure(",
                // The leaf shape counts too (#573 re-review): a
                // stray `.searchAnchored(SettingsCatalog.x.y)`
                // mounts a second view carrying an id the real
                // section already owns, and `scrollTo` then picks
                // arbitrarily. The container shapes were guarded
                // against that from the start; promoting the leaf
                // to the canonical door without counting it left
                // the same harm open on the more-used side.
                ".searchAnchored(",
            ] {
                for argument in SourceScan.firstArguments(
                    of: needle,
                    in: source
                ) {
                    classify(
                        argument,
                        file: name,
                        direct: &direct,
                        modeTabs: &modeTabs,
                        problems: &problems
                    )
                }
            }
        }

        #expect(
            problems.isEmpty,
            Comment(
                rawValue: problems.joined(separator: " | ")
            )
        )
        // Exact totals, so a needle that silently stops matching
        // cannot pass vacuously (part-1: a guard that cannot fire
        // is worse than none). 46 = the 49 section/disclosure-
        // mounted top-level declarations − 4 indirect (gaps and
        // drag, ×2 each) + 1 double-mounted (monitors); the
        // Show-it-in toggles self-anchor, outside this count.
        // #678 Phase 3 is +5 net: eight new colour declarations
        // plus Size & float's disclosure in, the two interim
        // colour cards and their two Advanced-colors drawers out.
        // Turn 10 adds Layout Defaults' live-preview and
        // spaces-using cards: 48.
        // 47 since turn 14b merged General's two cards.
        // 49 since turn 13a: Profiles' "Which profile loads"
        // card and its "For other setups" preset drawer, each
        // mounted once.
        // 48 since turn 13b: Monitors' second mount of
        // `spacePlacement` is gone — the picture and the
        // not-connected banner are gated rows inside one card
        // rather than two cards sharing an anchor id.
        // 49 since #754: the Borders card, mounted once.
        // 50 since #793: Advanced Colours' panel scene, mounted
        // once — in the panel rather than in the section body.
        // 51 since #794: the Spaces panel's preview, likewise
        // mounted in the panel and not in the section.
        // 51 since #875: deleted the install inventory card.
        // 52 since #1019: About's Guide link self-anchors, so
        // a search hit lands ON the link rather than on the
        // card around it.
        #expect(direct.values.reduce(0, +) == 52)
        // One parameterized layout-mode mount, not six literal
        // ones: turn 10's strip mounts the SELECTED layout's card
        // and nothing else, so the six anchor ids come from
        // `LayoutMode.placementTabs` at run time. That the strip
        // really walks that list — and so that every layout is
        // reachable — is
        // `LayoutDefaultsCensusRenderTests.stripWalksEveryLayout`;
        // this half only pins that no SECOND mount reintroduces a
        // duplicate id.
        #expect(modeTabs == ["*"])
        for (path, count) in direct.sorted(by: { $0.key < $1.key }) {
            let allowed = alternatelyMounted[path] ?? 1
            #expect(
                count == allowed,
                Comment(
                    rawValue:
                        "\(path) is mounted at \(count) sites, "
                        + "expected \(allowed). Co-mounted twins "
                        + "share one id, making scrollTo "
                        + "undefined — use per-instance "
                        + "declarations, or record the mutual "
                        + "exclusion in alternatelyMounted."
                )
            )
        }
        for path in alternatelyMounted.keys {
            #expect(
                direct[path] != nil,
                Comment(
                    rawValue:
                        "stale alternatelyMounted entry: \(path)"
                )
            )
        }
    }

    // MARK: - Classification

    private func classify(
        _ argument: String,
        file: String,
        direct: inout [String: Int],
        modeTabs: inout [String],
        problems: inout [String]
    ) {
        if let path = catalogPath(argument) {
            direct[path, default: 0] += 1
            return
        }
        if let mode = layoutModeArgument(argument) {
            modeTabs.append(mode)
            return
        }
        if argument.hasPrefix("L(") {
            let key =
                SourceScan.firstMatch(
                    in: argument,
                    pattern: #"L\(\s*"([a-z0-9_.]+)""#
                ) ?? "?"
            if literalTitleSites.contains("\(file): \(key)") {
                return
            }
            problems.append(
                "\(file): literal L(\"\(key)\") header — "
                    + "declare it in SettingsCatalog instead"
            )
            return
        }
        if indirectSites.contains("\(file): \(argument)") {
            return
        }
        problems.append(
            "\(file): unresolvable anchor argument "
                + "'\(argument)' — pass a catalog declaration "
                + "or allow-list it with a reason"
        )
    }

    private func catalogPath(_ argument: String) -> String? {
        SourceScan.firstMatch(
            in: argument,
            pattern: #"^SettingsCatalog\.(\w+\.\w+)$"#
        )
    }

    /// A layout-mode mount, literal (`.bsp`) or parameterized
    /// (`mode`). Since #678 turn 10 there is exactly one card and
    /// it takes the selected layout, so the parameterized form is
    /// the shipping shape and reports as `*`; the literal form
    /// stays recognised because a second, per-layout mount would
    /// otherwise read as an unresolvable argument rather than as
    /// what it is.
    private func layoutModeArgument(
        _ argument: String
    ) -> String? {
        SourceScan.firstMatch(
            in: argument,
            pattern:
                #"^SettingsCatalog\.layoutMode\(\.?(\w+)\)$"#
        )
        .map { $0 == "mode" ? "*" : $0 }
    }
}
