import Foundation

/// Shared primitives for the suites that exercise a
/// `scripts/*` localization tool by really spawning it
/// (`RenameKeyTests`, `DropKeyTests`, `MergeKeysTests`,
/// `LocalizationDriftGuardTests`, `LocalizationOrphanTests`).
///
/// Convention note: `.claude/rules/tests.md` prefers per-file
/// private helpers ("no shared test harness"). This file is the
/// second ratified exception, on the same terms as
/// `ReflectionParity.swift` — these are stateless mechanics
/// (spawn a process, drain its pipes, lay out a temp directory)
/// with no setup/teardown coupling and no assertions of their
/// own. The trigger was the #249 architect review on issue #252:
/// merge-keys' suite would have been the *fifth* hand-copied
/// spawn harness, so the copy was extracted here instead.
///
/// Two fixture shapes exist because the scripts resolve their
/// repo root two different ways, and that difference is real,
/// not incidental:
///
/// - **Repo-shaped** (`rename-key`, `drop-key`, `merge-keys`):
///   the script derives its root from its own `__file__` and has
///   no env-var override by design, so the test must copy the
///   script into a directory tree shaped like the real repo.
///   Use `makeRepoShapedFixture` + `runRepoScript`.
/// - **Env-var scoped** (`extract-keys`): the script honours
///   `KIWIDESK_EXTRACT_SOURCES` / `KIWIDESK_EXTRACT_LOCALES`, so
///   the real script runs in place against flat temp dirs. Use
///   `runPythonScript` directly with an `environment`.
///
/// Only the spawn primitive is shared by both.

/// The repo root, derived from this file's location.
func scriptFixtureRepoRoot(_ filePath: StaticString = #filePath)
    -> URL
{
    URL(fileURLWithPath: "\(filePath)")
        .deletingLastPathComponent()  // KiwiDeskCoreTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // repo root
}

/// Result of a spawned script run.
struct ScriptRun {
    let status: Int32
    let stdout: String
    let stderr: String
}

/// Spawns `python3 <script> <arguments>` and drains both pipes.
/// The one piece every script suite needs identically — a
/// divergent copy here would silently change what a suite
/// observes (a missed `stderr`, an undrained pipe) without
/// failing anything.
@discardableResult
func runPythonScript(
    at script: URL,
    arguments: [String],
    environment: [String: String]? = nil
) throws -> ScriptRun {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["python3", script.path] + arguments
    if let environment {
        process.environment = environment
    }
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    try process.run()
    // Read before waiting: a script that outstrips the pipe
    // buffer would otherwise block forever on write while the
    // test blocks on exit.
    let outData = stdoutPipe.fileHandleForReading
        .readDataToEndOfFile()
    let errData = stderrPipe.fileHandleForReading
        .readDataToEndOfFile()
    process.waitUntilExit()
    return ScriptRun(
        status: process.terminationStatus,
        stdout: String(data: outData, encoding: .utf8) ?? "",
        stderr: String(data: errData, encoding: .utf8) ?? ""
    )
}

/// A throwaway directory tree shaped like the real repo, so a
/// script that derives its root from `__file__` resolves into
/// the fixture instead of the developer's checkout.
struct RepoShapedFixture {
    let root: URL
    let cleanup: () -> Void

    /// Where a script writes without `--site`:
    /// `<root>/Sources/KiwiDeskCore/Resources/Locales`.
    var locales: URL {
        root
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDeskCore")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Locales")
    }

    /// Where a script writes *with* `--site`:
    /// `<root>/site/src/i18n`. A separate tree, so a `--site`
    /// test can prove the flag redirects rather than merely
    /// passing against the same directory.
    var siteLocales: URL {
        root
            .appendingPathComponent("site")
            .appendingPathComponent("src")
            .appendingPathComponent("i18n")
    }

    func dir(site: Bool) -> URL { site ? siteLocales : locales }

    /// Decodes one locale file as the flat `{key: string}` map
    /// the shipped catalogs use.
    func decodeLocale(
        _ name: String,
        site: Bool = false
    ) throws -> [String: String] {
        try JSONDecoder().decode(
            [String: String].self,
            from: Data(
                contentsOf: dir(site: site)
                    .appendingPathComponent(name)
            )
        )
    }

    /// Raw contents of a file under a locales directory, for the
    /// cases where the shape under test is not a flat map (a
    /// `missing_<locale>.json` worksheet).
    func rawLocaleFile(
        _ name: String,
        site: Bool = false
    ) throws -> Data {
        try Data(
            contentsOf: dir(site: site)
                .appendingPathComponent(name)
        )
    }

    func localeFileExists(
        _ name: String,
        site: Bool = false
    ) -> Bool {
        FileManager.default.fileExists(
            atPath: dir(site: site)
                .appendingPathComponent(name).path
        )
    }
}

/// Builds a `RepoShapedFixture` and writes `localeFiles` into
/// its locales directory. `prefix` only names the temp
/// directory, so a failing run is traceable to its suite.
func makeRepoShapedFixture(
    prefix: String,
    locales localeFiles: [String: String],
    siteLocales siteFiles: [String: String] = [:]
) throws -> RepoShapedFixture {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
    let fixture = RepoShapedFixture(
        root: root,
        cleanup: { try? FileManager.default.removeItem(at: root) }
    )
    for (dir, files) in [
        (fixture.locales, localeFiles),
        (fixture.siteLocales, siteFiles),
    ] where !files.isEmpty || dir == fixture.locales {
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        for (name, content) in files {
            try content.write(
                to: dir.appendingPathComponent(name),
                atomically: true,
                encoding: .utf8
            )
        }
    }
    return fixture
}

/// Copies `scripts/<name>` from the real repo into the fixture
/// and runs it there, so its `__file__`-derived root is the
/// fixture. Copying (not symlinking) is deliberate: Python
/// resolves a symlink back to the real repo.
@discardableResult
func runRepoScript(
    _ name: String,
    arguments: [String],
    in fixture: RepoShapedFixture,
    repoRoot: URL
) throws -> ScriptRun {
    let scriptsDir = fixture.root.appendingPathComponent("scripts")
    let copied = scriptsDir.appendingPathComponent(name)
    if !FileManager.default.fileExists(atPath: copied.path) {
        try FileManager.default.createDirectory(
            at: scriptsDir,
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(
            at: repoRoot.appendingPathComponent("scripts/\(name)"),
            to: copied
        )
    }
    return try runPythonScript(at: copied, arguments: arguments)
}
