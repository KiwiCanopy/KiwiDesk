import Foundation
import Testing

@testable import KiwiDesk

/// The render-site half of the catalog guards (#277 part 2),
/// direction one: the catalog is the one list, so the drift left
/// to catch is a declaration nobody renders — a dead search entry,
/// the shape part 1 shipped six of. Direction two (every anchor
/// primitive is FED a catalog declaration) is
/// `SettingsCatalogArgumentTests`; structural invariants over the
/// enumeration itself are `SettingsCatalogTests`.
@Suite("Settings catalog render sites")
struct SettingsCatalogSiteTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// A declaration nobody references is a dead search entry — a
    /// reveal on it scrolls nowhere and flashes nothing. Every
    /// catalog property name must appear (dotted) somewhere under
    /// `Settings/` outside the catalog files.
    @Test("every catalog declaration is referenced by a view")
    func catalogDeclarationsAreReferenced() throws {
        var rendered = ""
        for file in try SourceScan.swiftSources(under: settingsDir)
        where !SourceScan.isCatalogFile(
            file.lastPathComponent
        ) {
            rendered += SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
        }
        let names = SettingsDestination.allCases
            .flatMap { SettingsCatalog.entries(of: $0) }
            .compactMap { $0.propertyPath.last }
        #expect(names.count == 49)
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

    /// Catalog controls must be **stored** (`let` / stored
    /// `var`), never *computed* (`var x: SettingsControl { … }`).
    /// A computed property is invisible to `Mirror`, so the
    /// enumerator never sees it and `unenumerated(in:)` cannot
    /// either — it would ship rendered-but-unsearchable with every
    /// test green. This is the one enumerator gap reflection
    /// cannot self-check, so a source scan closes it.
    @Test("no catalog control is a computed property")
    func catalogControlsAreStored() throws {
        // Only the declaration files (`SettingsCatalog+*`), NOT
        // `SettingsControl.swift` — its `AnySettingsDrawer`
        // protocol legitimately declares `var control:
        // SettingsControl { get }`, which is a requirement, not a
        // catalog control.
        for file in try SourceScan.swiftSources(under: settingsDir)
        where SourceScan.isDeclarationFile(
            file.lastPathComponent
        ) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let hit = source.range(
                of:
                    #"\bvar\s+\w+\s*:\s*Settings(Control|Drawer)"#,
                options: .regularExpression
            )
            #expect(
                hit == nil,
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) declares a "
                        + "computed control — Mirror cannot see it, "
                        + "so it is unsearchable. Use `let`."
                )
            )
        }
    }
    /// Every `*Controls` declaration struct must be registered
    /// in `SettingsCatalog.container(of:)`, or reflection never
    /// reaches it — and an unregistered struct is invisible to
    /// every count guard above, since they all reflect over what
    /// IS registered. Contrived while the catalog was one file;
    /// live now that "add a `SettingsCatalog+*` slice" is the
    /// routine move (#573 architect review).
    @Test("every declaration struct is reachable")
    func declarationStructsAreReachable() throws {
        var declarations: [String] = []
        var corpus = ""
        for file in try SourceScan.swiftSources(under: settingsDir)
        where SourceScan.isDeclarationFile(
            file.lastPathComponent
        ) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            corpus += source
            declarations += SourceScan.allMatches(
                in: source,
                // Keyed on the naming convention, NOT on
                // `: Sendable` — registration as a `static let`
                // is what forces that conformance, so an
                // unregistered struct (the one shape this hunts)
                // is exactly the shape under no pressure to
                // carry it.
                pattern: #"struct (\w+)\b"#
            )
        }
        // Two legitimate ways to be reached, and reflection walks
        // exactly these: a destination container, registered as a
        // `static let` on `SettingsCatalog`; or a drawer's nested
        // children, mounted as `children:`. `container(of:)` is
        // an exhaustive switch, so the compiler already pins the
        // other direction — only a surplus struct can hide.
        #expect(declarations.count >= 10)
        for name in declarations {
            let registered =
                corpus.occurrences(of: "= \(name)()") > 0
            let nested =
                corpus.occurrences(of: "children: \(name)()") > 0
            #expect(
                registered || nested,
                Comment(
                    rawValue:
                        "\(name) is declared but never "
                        + "registered on SettingsCatalog nor "
                        + "mounted as a drawer's children — "
                        + "reflection never reaches it, so it "
                        + "ships rendered-but-unsearchable with "
                        + "every count guard still green"
                )
            )
        }
    }
}
