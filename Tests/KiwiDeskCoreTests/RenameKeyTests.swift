import Foundation
import Testing

/// Exercises `scripts/rename-key` (issue #9 review): a pure key
/// rename must preserve every locale's existing translation
/// value, and must reject a missing source key or a colliding
/// destination key rather than silently clobbering data.
@Suite("rename-key")
struct RenameKeyTests {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }

    /// `rename-key` has no env-var override (it always targets
    /// `Sources/KiwiDeskCore/Resources/Locales` under its own
    /// `__file__`-derived repo root) — so to test it against a
    /// throwaway fixture, `run(_:root:)` copies the script into
    /// a fixture tree shaped like the real repo
    /// (`<fixture>/scripts/rename-key` next to
    /// `<fixture>/Sources/KiwiDeskCore/Resources/Locales`), and
    /// this helper builds that fixture tree's locale files.
    private func makeFixtureRoot(
        locales localeFiles: [String: String]
    ) throws -> (root: URL, cleanup: () -> Void) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-rename-key-\(UUID().uuidString)"
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
        // Copy the real script into the fixture root so its
        // `__file__`-derived ROOT resolves to the fixture, not
        // the real repo — `rename-key` has no env-var override
        // by design (it always targets the real locale
        // directory for a human running it).
        let realScript = repoRoot.appendingPathComponent(
            "scripts/rename-key"
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
            .appendingPathComponent("rename-key")
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

    private func locales(in root: URL) -> URL {
        root
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDeskCore")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Locales")
    }

    @Test("renames the key in every locale file, keeping values")
    func renamesAcrossAllLocalesPreservingValues() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"menu.quit": "Quit KiwiDesk"}
            """#,
            "de.json": #"""
            {"menu.quit": "KiwiDesk beenden"}
            """#,
        ])
        defer { fixture.cleanup() }
        let result = try run(
            ["menu.quit", "menu.exit"],
            root: fixture.root
        )
        #expect(result.status == 0)

        let localesDir = locales(in: fixture.root)
        for (name, expected) in [
            ("en.json", "Quit KiwiDesk"),
            ("de.json", "KiwiDesk beenden"),
        ] {
            let data = try Data(
                contentsOf: localesDir.appendingPathComponent(
                    name
                )
            )
            let decoded = try JSONDecoder().decode(
                [String: String].self,
                from: data
            )
            #expect(decoded["menu.quit"] == nil)
            #expect(decoded["menu.exit"] == expected)
        }
    }

    @Test("fails when the old key is absent everywhere")
    func failsWhenOldKeyMissing() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"menu.quit": "Quit KiwiDesk"}
            """#
        ])
        defer { fixture.cleanup() }
        let result = try run(
            ["no.such.key", "some.new.key"],
            root: fixture.root
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("no.such.key"))
    }

    @Test("fails when the new key already exists")
    func failsWhenNewKeyCollides() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"menu.quit": "Quit KiwiDesk",
             "menu.exit": "Already taken"}
            """#
        ])
        defer { fixture.cleanup() }
        let result = try run(
            ["menu.quit", "menu.exit"],
            root: fixture.root
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("menu.exit"))

        // Nothing was touched on failure.
        let data = try Data(
            contentsOf: locales(in: fixture.root)
                .appendingPathComponent("en.json")
        )
        let decoded = try JSONDecoder().decode(
            [String: String].self,
            from: data
        )
        #expect(decoded["menu.quit"] == "Quit KiwiDesk")
        #expect(decoded["menu.exit"] == "Already taken")
    }

    @Test("only renames in locales that actually have the key")
    func onlyTouchesLocalesThatHaveTheKey() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"menu.quit": "Quit KiwiDesk"}
            """#,
            "fr.json": #"""
            {"menu.settings": "Réglages…"}
            """#,
        ])
        defer { fixture.cleanup() }
        let result = try run(
            ["menu.quit", "menu.exit"],
            root: fixture.root
        )
        #expect(result.status == 0)

        let frData = try Data(
            contentsOf: locales(in: fixture.root)
                .appendingPathComponent("fr.json")
        )
        let fr = try JSONDecoder().decode(
            [String: String].self,
            from: frData
        )
        // fr.json never had menu.quit — untouched, no
        // spurious menu.exit key created.
        #expect(fr == ["menu.settings": "Réglages…"])
    }
}
