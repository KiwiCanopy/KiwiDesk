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
        where !SettingsCatalogFiles.isCatalogFile(
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
        // Only the declaration files (`SettingsCatalog*`), NOT
        // `SettingsControl.swift` — its `AnySettingsDrawer`
        // protocol legitimately declares `var control:
        // SettingsControl { get }`, which is a requirement, not a
        // catalog control.
        for file in try SourceScan.swiftSources(under: settingsDir)
        where file.lastPathComponent.hasPrefix("SettingsCatalog") {
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
}

/// Which files ARE the catalog — everywhere else under
/// `Settings/` is a render site. One home because three suites
/// ask (`SettingsCatalogSiteTests`,
/// `SettingsCatalogArgumentTests`,
/// `SettingsAnchorPrimitiveTests`) and a copy that missed a
/// declaration file would read that file's own declarations as
/// render-site references, passing direction one vacuously.
/// The prefix is load-bearing: the declarations are split across
/// `SettingsCatalog+*.swift` by sidebar group, and a new slice
/// must be covered by existing.
enum SettingsCatalogFiles {
    static func isCatalogFile(_ name: String) -> Bool {
        name.hasPrefix("SettingsCatalog")
            || name == "SettingsControl.swift"
    }
}
