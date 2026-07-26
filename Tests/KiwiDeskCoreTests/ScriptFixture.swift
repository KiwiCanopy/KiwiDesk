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
/// Two fixture shapes exist, and the split is **historical, not
/// fundamental** — `extract-keys` was wired for env overrides
/// before the copy-into-a-fixture technique existed, and the
/// repo-shaped form would serve it too:
///
/// - **Repo-shaped** (`rename-key`, `drop-key`, `merge-keys`):
///   the script derives its root from its own `__file__` and has
///   no env-var override, so the test copies the script into a
///   directory tree shaped like the real repo. Use
///   `makeRepoShapedFixture` + `runRepoScript`.
/// - **Env-var scoped** (`extract-keys`): the script honours
///   `KIWIDESK_EXTRACT_SOURCES` / `KIWIDESK_EXTRACT_LOCALES`, so
///   the real script runs in place against flat temp dirs. Use
///   `runPythonScript` directly with an `environment`.
///
/// Converging the two on the repo-shaped form would be a real
/// improvement — it exercises each script exactly as shipped,
/// and it would let the test-only env hooks be deleted from
/// production code. It would also make `extract-keys --site`
/// testable at all: `SITE_LOCALES_DIR` is `__file__`-derived
/// with no override, so site mode is unreachable under the
/// env-var shape today. Left as a follow-up rather than widened
/// into this change.
///
/// Only the spawn primitive is shared by both.

/// The repo root, derived from **this** file's location.
///
/// `#filePath` is used in the body, never as a default argument:
/// a defaulted `#filePath` expands at the *call site*, so a suite
/// added one directory deeper would silently resolve `Tests/` as
/// the repo root and fail on a confusing copy error.
func scriptFixtureRepoRoot() -> URL {
    URL(fileURLWithPath: #filePath)
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
    // Read before waiting, so a script whose stdout outgrows the
    // pipe buffer cannot block on write while the test blocks on
    // exit. This is sequential, so it is not a general guarantee:
    // a child that filled its *stderr* buffer before closing
    // stdout would still deadlock. Sound for these scripts (a few
    // lines of stderr at most) and strictly better than the
    // hand-copies it replaced, one of which never drained stdout
    // at all. Concurrent drains are the fix if that ever changes.
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

    /// Writes Swift files into `<root>/Sources/KiwiDesk`, one of
    /// the two trees `extract-keys` scans by default. Lets a
    /// repo-shaped fixture host `extract-keys` too, which is what
    /// a cross-script round trip (merge-keys → extract-keys)
    /// needs — the env-var shape cannot host `merge-keys`.
    func writeSources(_ files: [String: String]) throws {
        let dir =
            root
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDesk")
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
///
/// Every `scripts/*.py` module is copied alongside it. Python
/// resolves a plain `import` against the script's own directory,
/// so a tool that shares a helper module (`merge-keys` and
/// `extract-keys` both import `localization_guards`) would fail
/// at import time in a fixture holding only the entry point.
@discardableResult
func runRepoScript(
    _ name: String,
    arguments: [String],
    in fixture: RepoShapedFixture,
    repoRoot: URL
) throws -> ScriptRun {
    let scriptsDir = fixture.root.appendingPathComponent("scripts")
    let source = repoRoot.appendingPathComponent("scripts")
    let modules = try FileManager.default
        .contentsOfDirectory(atPath: source.path)
        .filter { $0.hasSuffix(".py") }
    try FileManager.default.createDirectory(
        at: scriptsDir,
        withIntermediateDirectories: true
    )
    // Per file, not gated on the entry point: a test that runs two
    // tools in one fixture (merge-keys then extract-keys) copies
    // the second entry point while the shared modules are already
    // there, and copyItem onto an existing path throws.
    for file in [name] + modules {
        let destination = scriptsDir.appendingPathComponent(file)
        guard
            !FileManager.default.fileExists(
                atPath: destination.path
            )
        else { continue }
        try FileManager.default.copyItem(
            at: source.appendingPathComponent(file),
            to: destination
        )
    }
    return try runPythonScript(
        at: scriptsDir.appendingPathComponent(name),
        arguments: arguments
    )
}
