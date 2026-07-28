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
        // Aliases of `SettingsCatalog.appearance.gapsPerEdge` /
        // `.gapsPerAxis` — the same values, hoisted so the six
        // `GapRow`s can reach the children tersely.
        "GapsEditor.swift: perEdge",
        "GapsEditor.swift: perAxis",
        // The drag column helper takes its `SettingsControl` as
        // a parameter; both callers pass catalog declarations
        // (`dragGhost` / `dragDropZone`), which the dotted-
        // reference sweep still covers.
        "DragVisualsEditor.swift: control",
        // `LayoutAppBarGroup` renders twice co-mounted; each
        // mount receives its own instance declaration from
        // `BarsSection` (`monocleBarOverrides` /
        // `scrollingBarOverrides`).
        "AppBarLayoutGroup.swift: overridesDrawer",
    ]

    /// The one sanctioned literal-`L()` `SettingsSection` title:
    /// a computed per-instance heading (`"%1$@ bar"`), which can
    /// never be a static catalog entry. It renders unanchored.
    private let literalTitleSites: Set<String> = [
        "AppBarLayoutGroup.swift: app_bar.layout.title"
    ]

    /// Direct catalog references legitimately mounted at two
    /// sites. **Mutual exclusion is the only admissible
    /// reason** — the sites must never co-render, or the shared
    /// id is ambiguous.
    private let alternatelyMounted: [String: Int] = [
        // The two bar colour drawers mount ONE surface-free
        // declaration; `BarsSection` renders one editor per
        // `switch model.nav.barEditor`.
        "bars.advancedColors": 2,
        // `MonitorsSection`'s cards section and its
        // "not connected" read-only twin are if/else branches.
        "monitors.spacePlacement": 2,
    ]

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
        where !SettingsCatalogFiles.isCatalogFile(
            file.lastPathComponent
        ) {
            let name = file.lastPathComponent
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            for needle in [
                "SettingsSection(", "SettingsDisclosure(",
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
        // is worse than none). 37 = the 41 section/disclosure-
        // mounted top-level declarations − 6 indirect (gaps/drag/
        // overrides ×2 each) + 2 double-mounted; the two bar-
        // switch entries self-anchor, outside this count.
        #expect(direct.values.reduce(0, +) == 37)
        #expect(
            modeTabs.sorted() == [
                "bsp", "grid", "monocle", "scrolling", "stack",
                "track",
            ]
        )
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

    private func layoutModeArgument(
        _ argument: String
    ) -> String? {
        SourceScan.firstMatch(
            in: argument,
            pattern: #"^SettingsCatalog\.layoutMode\(\.(\w+)\)$"#
        )
    }
}
