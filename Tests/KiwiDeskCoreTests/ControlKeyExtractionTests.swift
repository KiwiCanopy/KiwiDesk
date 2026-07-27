import Foundation
import Testing

/// Exercises `scripts/extract-keys`' second call shape (#277
/// part 2): `SettingsControl("key", "English", …)` and
/// `SettingsDrawer("key", "English", …)` declarations in the
/// Settings catalog carry localized tuples exactly like `L()`
/// call sites, so the scanner must extract them — otherwise
/// every migrated key would read as orphaned and
/// `extract-keys --check` would go quiet on the catalog, the
/// gate that catches a scanner that silently stopped matching.
/// Sibling suite per AGENTS.md §5 (one per localization-script
/// change), env-var-scoped like `LocalizationDriftGuardTests`.
@Suite("extract-keys control descriptors")
struct ControlKeyExtractionTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    private func makeFixture(
        _ swiftFiles: [String: String]
    ) throws -> (sources: URL, locales: URL, cleanup: () -> Void) {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-control-keys-\(UUID().uuidString)"
            )
        let sources = base.appendingPathComponent("Sources")
        let locales = base.appendingPathComponent("Locales")
        try FileManager.default.createDirectory(
            at: sources,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: locales,
            withIntermediateDirectories: true
        )
        for (name, content) in swiftFiles {
            try content.write(
                to: sources.appendingPathComponent(name),
                atomically: true,
                encoding: .utf8
            )
        }
        return (
            sources, locales,
            { try? FileManager.default.removeItem(at: base) }
        )
    }

    @discardableResult
    private func runExtractKeys(
        sources: URL,
        locales: URL
    ) throws -> ScriptRun {
        try runPythonScript(
            at: repoRoot.appendingPathComponent(
                "scripts/extract-keys"
            ),
            arguments: [],
            environment: [
                "KIWIDESK_EXTRACT_SOURCES": sources.path,
                "KIWIDESK_EXTRACT_LOCALES": locales.path,
            ]
        )
    }

    private func extracted(
        _ locales: URL
    ) throws -> [String: String] {
        try JSONDecoder().decode(
            [String: String].self,
            from: Data(
                contentsOf: locales.appendingPathComponent(
                    "en.json"
                )
            )
        )
    }

    @Test("a SettingsControl declaration is extracted")
    func controlDeclarationIsExtracted() throws {
        let fixture = try makeFixture([
            "Catalog.swift": #"""
            struct Controls {
                let gapsCard = SettingsControl(
                    "gaps.title",
                    "Gaps"
                )
                let styleCard = SettingsControl(
                    "app_bar.global_style.title",
                    "Global style",
                    surface: .bar(.appBar)
                )
            }
            """#
        ])
        defer { fixture.cleanup() }
        let result = try runExtractKeys(
            sources: fixture.sources,
            locales: fixture.locales
        )
        #expect(result.status == 0)
        let mapping = try extracted(fixture.locales)
        #expect(mapping["gaps.title"] == "Gaps")
        #expect(
            mapping["app_bar.global_style.title"]
                == "Global style"
        )
    }

    @Test("a SettingsDrawer declaration is extracted")
    func drawerDeclarationIsExtracted() throws {
        let fixture = try makeFixture([
            "Catalog.swift": #"""
            struct Controls {
                let perEdge = SettingsDrawer(
                    "gaps.per_edge",
                    "Per-edge…",
                    children: GapEdgeControls()
                )
                let overrides = SettingsDrawer(
                    "app_bar.layout.overrides",
                    "Overrides",
                    surface: .bar(.appBar),
                    instance: "monocle"
                )
            }
            """#
        ])
        defer { fixture.cleanup() }
        let result = try runExtractKeys(
            sources: fixture.sources,
            locales: fixture.locales
        )
        #expect(result.status == 0)
        let mapping = try extracted(fixture.locales)
        #expect(mapping["gaps.per_edge"] == "Per-edge…")
        #expect(
            mapping["app_bar.layout.overrides"] == "Overrides"
        )
    }

    /// The drift guard must reach across call shapes: one key
    /// declared in the catalog and rendered via `L()` elsewhere
    /// with different English is the same silent-disagreement
    /// bug the guard exists for.
    @Test("drift between L() and a descriptor fails")
    func crossShapeDriftFails() throws {
        let fixture = try makeFixture([
            "Catalog.swift": #"""
            let a = SettingsControl("gaps.title", "Gaps")
            """#,
            "View.swift": #"""
            let b = L("gaps.title", "Spacing")
            """#,
        ])
        defer { fixture.cleanup() }
        let result = try runExtractKeys(
            sources: fixture.sources,
            locales: fixture.locales
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("gaps.title"))
        #expect(result.stderr.contains("Gaps"))
        #expect(result.stderr.contains("Spacing"))
    }

    /// Same key, same English, both shapes — the migrated
    /// steady state (the catalog declares, `LayoutModeGlyph`
    /// still renders some tuples via `L()`).
    @Test("identical English across shapes succeeds")
    func identicalCrossShapeSucceeds() throws {
        let fixture = try makeFixture([
            "Catalog.swift": #"""
            let a = SettingsControl("gaps.title", "Gaps")
            """#,
            "View.swift": #"""
            let b = L("gaps.title", "Gaps")
            """#,
        ])
        defer { fixture.cleanup() }
        let result = try runExtractKeys(
            sources: fixture.sources,
            locales: fixture.locales
        )
        #expect(result.status == 0)
        let mapping = try extracted(fixture.locales)
        #expect(mapping == ["gaps.title": "Gaps"])
    }

    /// A doc-comment example must not mint a phantom key — the
    /// same comment-awareness `L()` extraction has.
    @Test("a doc-comment descriptor example is ignored")
    func docCommentExampleIsIgnored() throws {
        let fixture = try makeFixture([
            "Catalog.swift": #"""
            /// Declare it like
            /// `SettingsControl("phantom.key", "Phantom")`.
            let a = SettingsControl("real.key", "Real value")
            """#
        ])
        defer { fixture.cleanup() }
        let result = try runExtractKeys(
            sources: fixture.sources,
            locales: fixture.locales
        )
        #expect(result.status == 0)
        let mapping = try extracted(fixture.locales)
        #expect(mapping == ["real.key": "Real value"])
    }
}
