import Foundation
import Testing

/// Exercises `scripts/extract-keys`' same-key/different-English
/// drift guard (issue #9) end to end, so a regression in the
/// tool itself fails `swift test`/CI even if nobody happens to
/// run the script by hand. Points the scanner at a throwaway
/// fixture tree via `KIWIDESK_EXTRACT_SOURCES` /
/// `KIWIDESK_EXTRACT_LOCALES` (never set outside tests — the
/// human-facing CLI always scans the real `Sources/KiwiDesk`).
@Suite("extract-keys drift guard")
struct LocalizationDriftGuardTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    private func makeFixture(
        _ swiftFiles: [String: String]
    ) throws -> (sources: URL, locales: URL, cleanup: () -> Void) {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-extract-keys-\(UUID().uuidString)"
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
        // `extract-keys` is the env-var-scoped shape: it honours
        // these two overrides, so the real script runs in place
        // against flat temp dirs — no fixture tree needed (see
        // `ScriptFixture.swift`).
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

    @Test("a clean tree exits 0 and writes en.json")
    func cleanTreeSucceeds() throws {
        let fixture = try makeFixture([
            "A.swift": #"""
            let a = L("greeting", "Hello")
            """#,
            "B.swift": #"""
            let b = L("farewell", "Goodbye")
            """#,
        ])
        defer { fixture.cleanup() }
        let result = try runExtractKeys(
            sources: fixture.sources,
            locales: fixture.locales
        )
        #expect(result.status == 0)
        let enJSON = fixture.locales.appendingPathComponent(
            "en.json"
        )
        let data = try Data(contentsOf: enJSON)
        let decoded = try JSONDecoder().decode(
            [String: String].self,
            from: data
        )
        #expect(decoded["greeting"] == "Hello")
        #expect(decoded["farewell"] == "Goodbye")
    }

    @Test(
        "the same key with two different English strings fails"
    )
    func driftingKeyFails() throws {
        let fixture = try makeFixture([
            "A.swift": #"""
            let a = L("menu.quit", "Quit KiwiDesk")
            """#,
            "B.swift": #"""
            let b = L("menu.quit", "Exit KiwiDesk")
            """#,
        ])
        defer { fixture.cleanup() }
        let result = try runExtractKeys(
            sources: fixture.sources,
            locales: fixture.locales
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("menu.quit"))
        #expect(result.stderr.contains("Quit KiwiDesk"))
        #expect(result.stderr.contains("Exit KiwiDesk"))
    }

    @Test("the same key with the same English string succeeds")
    func repeatedIdenticalKeySucceeds() throws {
        let fixture = try makeFixture([
            "A.swift": #"""
            let a = L("shared.key", "Same text")
            """#,
            "B.swift": #"""
            let b = L("shared.key", "Same text")
            """#,
        ])
        defer { fixture.cleanup() }
        let result = try runExtractKeys(
            sources: fixture.sources,
            locales: fixture.locales
        )
        #expect(result.status == 0)
    }

    @Test("a doc-comment example call site is not extracted")
    func docCommentExampleIsIgnored() throws {
        let fixture = try makeFixture([
            "A.swift": #"""
            /// Call it like `L("key", "English")`, e.g.
            /// `L("menu.quit", "Quit KiwiDesk")`.
            let a = L("real.key", "Real value")
            """#
        ])
        defer { fixture.cleanup() }
        let result = try runExtractKeys(
            sources: fixture.sources,
            locales: fixture.locales
        )
        #expect(result.status == 0)
        let enJSON = fixture.locales.appendingPathComponent(
            "en.json"
        )
        let data = try Data(contentsOf: enJSON)
        let decoded = try JSONDecoder().decode(
            [String: String].self,
            from: data
        )
        #expect(decoded == ["real.key": "Real value"])
        #expect(decoded["key"] == nil)
        #expect(decoded["menu.quit"] == nil)
    }

    @Test("a slash pair inside a string literal is preserved")
    func slashSlashInsideStringIsPreserved() throws {
        let fixture = try makeFixture([
            "A.swift": #"""
            let a = L("url.key", "See https://example.com")
            """#
        ])
        defer { fixture.cleanup() }
        let result = try runExtractKeys(
            sources: fixture.sources,
            locales: fixture.locales
        )
        #expect(result.status == 0)
        let enJSON = fixture.locales.appendingPathComponent(
            "en.json"
        )
        let data = try Data(contentsOf: enJSON)
        let decoded = try JSONDecoder().decode(
            [String: String].self,
            from: data
        )
        #expect(
            decoded["url.key"] == "See https://example.com"
        )
    }
}
