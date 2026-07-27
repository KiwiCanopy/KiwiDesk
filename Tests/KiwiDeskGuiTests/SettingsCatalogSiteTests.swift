import Foundation
import Testing

@testable import KiwiDesk

/// The render-site half of the catalog guards (#277 part 2): the
/// catalog is the one list, so the drift left to catch is a
/// declaration nobody renders (a dead search entry — the shape
/// part 1 shipped six of) and an anchor primitive fed something
/// other than a catalog declaration. Structural invariants over
/// the enumeration itself live in `SettingsCatalogTests`.
@Suite("Settings catalog render sites")
struct SettingsCatalogSiteTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// The catalog's own files — everywhere else is a render
    /// site.
    private func isCatalogFile(_ name: String) -> Bool {
        name == "SettingsCatalog.swift"
            || name == "SettingsControl.swift"
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

    /// Direction one: a declaration nobody references is a dead
    /// search entry — a reveal on it scrolls nowhere and flashes
    /// nothing. Every catalog property name must appear (dotted)
    /// somewhere under `Settings/` outside the catalog files.
    @Test("every catalog declaration is referenced by a view")
    func catalogDeclarationsAreReferenced() throws {
        var rendered = ""
        for file in try SourceScan.swiftSources(under: settingsDir)
        where !isCatalogFile(file.lastPathComponent) {
            rendered += SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
        }
        let names = SettingsDestination.allCases
            .flatMap { SettingsCatalog.entries(of: $0) }
            .compactMap { $0.propertyPath.last }
        #expect(names.count == 46)
        for name in names {
            #expect(
                rendered.occurrences(of: ".\(name)") >= 1,
                Comment(
                    rawValue:
                        "\(name) is declared in the catalog but "
                        + "referenced by no view — a search hit "
                        + "on it reveals nothing"
                )
            )
        }
    }

    /// Direction two: every `SettingsSection(` /
    /// `SettingsDisclosure(` first argument is a catalog
    /// declaration (counted, so a co-mounted double reference
    /// trips), an allow-listed indirect parameter, or the one
    /// sanctioned computed title. A literal `L()` header fails:
    /// declaring it in the catalog is what makes it findable.
    @Test("anchor primitives take catalog declarations")
    func anchorPrimitivesTakeCatalogDeclarations() throws {
        var direct: [String: Int] = [:]
        var modeTabs: [String] = []
        var problems: [String] = []

        for file in try SourceScan.swiftSources(under: settingsDir)
        where !isCatalogFile(file.lastPathComponent) {
            let name = file.lastPathComponent
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            for needle in [
                "SettingsSection(", "SettingsDisclosure(",
            ] {
                for argument in firstArguments(
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
        // Exact totals, so a needle that silently stops
        // matching cannot pass by matching nothing (the part-1
        // lesson: a guard that cannot fire is worse than none).
        // 36 = the 40 top-level declarations, minus the six
        // reached through allow-listed indirect parameters
        // (gaps drawers ×2, drag columns ×2, layout overrides
        // ×2), plus the two double-mounted ones.
        #expect(direct.values.reduce(0, +) == 36)
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

    /// The first argument expression of every `needle(` call in
    /// `source`, whitespace-normalized.
    private func firstArguments(
        of needle: String,
        in source: String
    ) -> [String] {
        let text = Array(source)
        let wanted = Array(needle)
        var out: [String] = []
        var i = 0
        while i + wanted.count <= text.count {
            guard Array(text[i..<(i + wanted.count)]) == wanted
            else {
                i += 1
                continue
            }
            var cursor = i + wanted.count - 1
            guard
                let args = SourceScan.balanced(
                    text,
                    from: &cursor,
                    open: "(",
                    close: ")"
                )
            else {
                i += wanted.count
                continue
            }
            out.append(firstArgument(of: args))
            i = cursor
        }
        return out
    }

    /// Everything before the first top-level comma, collapsed to
    /// single spaces (string- and nesting-aware).
    private func firstArgument(of args: String) -> String {
        var depth = 0
        var inString = false
        var result = ""
        var previous: Character?
        for character in args {
            if inString {
                result.append(character)
                if character == "\"", previous != "\\" {
                    inString = false
                }
                previous = character
                continue
            }
            switch character {
            case "\"":
                inString = true
            case "(", "[", "{":
                depth += 1
            case ")", "]", "}":
                depth -= 1
            case ",":
                if depth == 0 {
                    return normalize(result)
                }
            default:
                break
            }
            result.append(character)
            previous = character
        }
        return normalize(result)
    }

    private func normalize(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .replacingOccurrences(of: " .", with: ".")
    }
}
