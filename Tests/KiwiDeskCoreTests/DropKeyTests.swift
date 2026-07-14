import Foundation
import Testing

/// Exercises `scripts/drop-key` (issue #249): dropping a key
/// whose English meaning changed must remove it from every
/// shipped translation, never touch the generated en.json, and
/// reject keys present nowhere (typo guard) without touching
/// any file.
@Suite("drop-key")
struct DropKeyTests {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }

    /// Same fixture discipline as `RenameKeyTests`: the script
    /// derives its repo root from `__file__`, so the test
    /// copies it into a fixture tree shaped like the real repo.
    private func makeFixtureRoot(
        locales localeFiles: [String: String]
    ) throws -> (root: URL, cleanup: () -> Void) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-drop-key-\(UUID().uuidString)"
            )
        let locales =
            root
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDeskCore")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Locales")
        try FileManager.default.createDirectory(
            at: locales,
            withIntermediateDirectories: true
        )
        for (name, content) in localeFiles {
            try content.write(
                to: locales.appendingPathComponent(name),
                atomically: true,
                encoding: .utf8
            )
        }
        return (
            root,
            { try? FileManager.default.removeItem(at: root) }
        )
    }

    @discardableResult
    private func run(
        _ arguments: [String],
        root: URL
    ) throws -> (status: Int32, stdout: String, stderr: String) {
        let realScript = repoRoot.appendingPathComponent(
            "scripts/drop-key"
        )
        let fixtureScriptsDir = root.appendingPathComponent(
            "scripts"
        )
        try FileManager.default.createDirectory(
            at: fixtureScriptsDir,
            withIntermediateDirectories: true
        )
        let fixtureScript =
            fixtureScriptsDir
            .appendingPathComponent("drop-key")
        try FileManager.default.copyItem(
            at: realScript,
            to: fixtureScript
        )

        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: "/usr/bin/env"
        )
        process.arguments =
            ["python3", fixtureScript.path]
            + arguments
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()
        let stdout =
            String(
                data: stdoutPipe.fileHandleForReading
                    .readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
        let stderr =
            String(
                data: stderrPipe.fileHandleForReading
                    .readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
        return (process.terminationStatus, stdout, stderr)
    }

    private func decoded(
        _ name: String,
        in root: URL
    ) throws -> [String: String] {
        let url =
            root
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDeskCore")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Locales")
            .appendingPathComponent(name)
        return try JSONDecoder().decode(
            [String: String].self,
            from: Data(contentsOf: url)
        )
    }

    @Test("drops from every translation, never from en.json")
    func dropsFromTranslationsNotEnglish() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"gap.hint": "New meaning", "menu.quit": "Quit"}
            """#,
            "de.json": #"""
            {"gap.hint": "Alte Bedeutung", "menu.quit": "Ende"}
            """#,
            "fr.json": #"""
            {"gap.hint": "Vieux sens"}
            """#,
        ])
        defer { fixture.cleanup() }
        let result = try run(["gap.hint"], root: fixture.root)
        #expect(result.status == 0)

        let en = try decoded("en.json", in: fixture.root)
        #expect(en["gap.hint"] == "New meaning")
        let de = try decoded("de.json", in: fixture.root)
        #expect(de == ["menu.quit": "Ende"])
        let fr = try decoded("fr.json", in: fixture.root)
        #expect(fr == [:])
    }

    @Test("fails atomically when any key exists nowhere")
    func failsAtomicallyOnUnknownKey() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"gap.hint": "New meaning"}
            """#,
            "de.json": #"""
            {"gap.hint": "Alte Bedeutung"}
            """#,
        ])
        defer { fixture.cleanup() }
        // gap.hint exists in de; no.such.key nowhere — the
        // batch must fail without dropping gap.hint.
        let result = try run(
            ["gap.hint", "no.such.key"],
            root: fixture.root
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("no.such.key"))
        let de = try decoded("de.json", in: fixture.root)
        #expect(de["gap.hint"] == "Alte Bedeutung")
    }

    @Test("key present only in en.json counts as nowhere")
    func englishOnlyKeyIsRejected() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"fresh.key": "Brand new"}
            """#,
            "de.json": #"""
            {"menu.quit": "Ende"}
            """#,
        ])
        defer { fixture.cleanup() }
        // A brand-new key has no stale translations to drop —
        // treat as a mistake, not a no-op success.
        let result = try run(["fresh.key"], root: fixture.root)
        #expect(result.status != 0)
        #expect(result.stderr.contains("fresh.key"))
    }

    @Test("drops multiple keys, including empty-string values")
    func dropsMultipleKeysAndEmptyValues() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"a.key": "A", "b.key": "B"}
            """#,
            "de.json": #"""
            {"a.key": "", "b.key": "Be", "menu.quit": "Ende"}
            """#,
        ])
        defer { fixture.cleanup() }
        let result = try run(
            ["a.key", "b.key"],
            root: fixture.root
        )
        #expect(result.status == 0)
        let de = try decoded("de.json", in: fixture.root)
        #expect(de == ["menu.quit": "Ende"])
    }
}
