import Foundation
import Testing

/// Exercises `scripts/extract-keys --check`'s orphan warning and
/// `scripts/extract-keys --prune` (issue #9 review): a key
/// removed or renamed in code leaves stale translations behind
/// in shipped `<locale>.json` files, and these two paths are how
/// a maintainer discovers and cleans that up. Fixture-scoped via
/// `KIWIDESK_EXTRACT_SOURCES` / `KIWIDESK_EXTRACT_LOCALES`, same
/// convention as `LocalizationDriftGuardTests`.
@Suite("extract-keys orphan detection and pruning")
struct LocalizationOrphanTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    private func makeFixture(
        swift swiftFiles: [String: String],
        locales localeFiles: [String: String] = [:]
    ) throws -> (sources: URL, locales: URL, cleanup: () -> Void) {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-extract-keys-orphan-\(UUID().uuidString)"
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
        for (name, content) in localeFiles {
            try content.write(
                to: locales.appendingPathComponent(name),
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
    private func run(
        _ arguments: [String],
        sources: URL,
        locales: URL
    ) throws -> ScriptRun {
        // `extract-keys` is the env-var-scoped shape: it
        // honours these two overrides, so the real script
        // runs in place against flat temp dirs — no fixture
        // tree needed (see `ScriptFixture.swift`).
        try runPythonScript(
            at: repoRoot.appendingPathComponent(
                "scripts/extract-keys"
            ),
            arguments: arguments,
            environment: [
                "KIWIDESK_EXTRACT_SOURCES": sources.path,
                "KIWIDESK_EXTRACT_LOCALES": locales.path,
            ]
        )
    }

    @Test(
        "--check warns (but does not fail) on an orphan key"
    )
    func checkWarnsWithoutFailing() throws {
        let fixture = try makeFixture(
            swift: [
                "A.swift": #"""
                let a = L("still.used", "Still used")
                """#
            ],
            locales: [
                "de.json": #"""
                {"still.used": "Wird noch verwendet",
                 "long.gone": "Verwaist"}
                """#,
                "en.json": #"""
                {"still.used": "Still used"}
                """#,
            ]
        )
        defer { fixture.cleanup() }
        let result = try run(
            ["--check"],
            sources: fixture.sources,
            locales: fixture.locales
        )
        // Orphans alone must never fail the gate.
        #expect(result.status == 0)
        #expect(result.stdout.contains("long.gone"))
        #expect(result.stdout.contains("de.json"))
    }

    @Test("--prune removes only orphan keys, from every locale")
    func pruneRemovesOnlyOrphans() throws {
        let fixture = try makeFixture(
            swift: [
                "A.swift": #"""
                let a = L("still.used", "Still used")
                """#
            ],
            locales: [
                "de.json": #"""
                {"still.used": "Wird noch verwendet",
                 "long.gone": "Verwaist"}
                """#,
                "fr.json": #"""
                {"still.used": "Encore utilisé",
                 "another.orphan": "Orpheline"}
                """#,
                "en.json": #"""
                {"still.used": "Still used"}
                """#,
            ]
        )
        defer { fixture.cleanup() }
        let result = try run(
            ["--prune"],
            sources: fixture.sources,
            locales: fixture.locales
        )
        #expect(result.status == 0)

        let deData = try Data(
            contentsOf: fixture.locales
                .appendingPathComponent("de.json")
        )
        let de = try JSONDecoder().decode(
            [String: String].self,
            from: deData
        )
        #expect(de == ["still.used": "Wird noch verwendet"])

        let frData = try Data(
            contentsOf: fixture.locales
                .appendingPathComponent("fr.json")
        )
        let fr = try JSONDecoder().decode(
            [String: String].self,
            from: frData
        )
        #expect(fr == ["still.used": "Encore utilisé"])
    }

    @Test("--prune is a no-op when there are no orphans")
    func pruneNoOpWhenClean() throws {
        let fixture = try makeFixture(
            swift: [
                "A.swift": #"""
                let a = L("still.used", "Still used")
                """#
            ],
            locales: [
                "de.json": #"""
                {"still.used": "Wird noch verwendet"}
                """#,
                "en.json": #"""
                {"still.used": "Still used"}
                """#,
            ]
        )
        defer { fixture.cleanup() }
        let result = try run(
            ["--prune"],
            sources: fixture.sources,
            locales: fixture.locales
        )
        #expect(result.status == 0)
        #expect(result.stdout.contains("no orphan keys"))
    }

    // MARK: - Malformed locale file (hard fail, issue #9 review)

    @Test("--check hard-fails on invalid JSON in a locale file")
    func checkFailsOnInvalidJSON() throws {
        let fixture = try makeFixture(
            swift: [
                "A.swift": #"""
                let a = L("still.used", "Still used")
                """#
            ],
            locales: [
                "de.json": "{ this is not valid json",
                "en.json": #"""
                {"still.used": "Still used"}
                """#,
            ]
        )
        defer { fixture.cleanup() }
        let result = try run(
            ["--check"],
            sources: fixture.sources,
            locales: fixture.locales
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("de.json"))
    }

    @Test("--check hard-fails when a locale value isn't flat")
    func checkFailsOnNonFlatShape() throws {
        let fixture = try makeFixture(
            swift: [
                "A.swift": #"""
                let a = L("still.used", "Still used")
                """#
            ],
            locales: [
                "de.json": #"""
                {"still.used": {"nested": "object"}}
                """#,
                "en.json": #"""
                {"still.used": "Still used"}
                """#,
            ]
        )
        defer { fixture.cleanup() }
        let result = try run(
            ["--check"],
            sources: fixture.sources,
            locales: fixture.locales
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("de.json"))
        #expect(result.stderr.contains("still.used"))
    }

    @Test("--check hard-fails when a locale file is a JSON array")
    func checkFailsOnNonObjectRoot() throws {
        let fixture = try makeFixture(
            swift: [
                "A.swift": #"""
                let a = L("still.used", "Still used")
                """#
            ],
            locales: [
                "de.json": #"""
                ["not", "a", "map"]
                """#,
                "en.json": #"""
                {"still.used": "Still used"}
                """#,
            ]
        )
        defer { fixture.cleanup() }
        let result = try run(
            ["--check"],
            sources: fixture.sources,
            locales: fixture.locales
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("de.json"))
    }
}
