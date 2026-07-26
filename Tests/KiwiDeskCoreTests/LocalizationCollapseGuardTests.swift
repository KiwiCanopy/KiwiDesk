import Foundation
import Testing

/// Exercises the collapsed-translation guard (issue #95): one
/// locale reusing a single value for many unrelated English
/// strings.
///
/// This is the guard that caught the worst defect in the corpus —
/// `it.json` and `pt-BR.json` had **every** interpolated string
/// replaced with one filler, 48 keys each. It is also the one the
/// other five all pass: the filler was fluent Italian, in the
/// right script, free of English residue, and carried the right
/// placeholders. Nothing but "this value is doing too many jobs"
/// distinguishes it.
///
/// Fixtures are written here, never read from the shipped
/// catalogs, so coverage never depends on the corpus staying
/// dirty.
@Suite("extract-keys collapse guard")
struct LocalizationCollapseGuardTests {
    /// The real defect's shape: distinct English strings, all
    /// interpolated, all translated to one filler.
    @Test("one filler across interpolated keys fails")
    func specifierFillerFails() throws {
        let result = try CollapseFixture.check(
            english: [
                "a.about": "About %1$@",
                "a.hide": "Hide %1$@",
                "a.help": "Help: %1$@",
            ],
            catalog: [
                "a.about": "Opzione %1$@",
                "a.hide": "Opzione %1$@",
                "a.help": "Opzione %1$@",
            ]
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("unrelated key"))
        #expect(result.stderr.contains("one filler"))
    }

    /// Two is deliberately *not* enough, even with a specifier.
    /// `app_bar.preview.caption` and `space_bar.preview.caption`
    /// legitimately share one English string today, so a purely
    /// cosmetic edit to one of them would make the English distinct
    /// and redden all eleven catalogs at once — and §5 says a
    /// cosmetic edit keeps translations. The real defect had groups
    /// of 37, 4, 4 and 3, so requiring 3 loses nothing.
    @Test("two interpolated keys are not yet a collapse")
    func twoInterpolatedKeysPass() throws {
        let result = try CollapseFixture.check(
            english: [
                "a.about": "About %1$@", "a.hide": "Hide %1$@",
            ],
            catalog: [
                "a.about": "Opzione %1$@",
                "a.hide": "Opzione %1$@",
            ]
        )
        #expect(result.status == 0)
    }

    /// The specifier clause must not fire on a *shared* English
    /// string — that is one decision translated once, not a
    /// filler. `%1$@ bar` and `%1$@ bar` are the same job.
    @Test("one English string reused is not a collapse")
    func sharedEnglishIsNotACollapse() throws {
        let result = try CollapseFixture.check(
            english: [
                "a.one": "About %1$@", "a.two": "About %1$@",
            ],
            catalog: [
                "a.one": "Informazioni su %1$@",
                "a.two": "Informazioni su %1$@",
            ]
        )
        #expect(result.status == 0)
    }

    /// Without a specifier the bar is five distinct English
    /// strings, because near-synonyms legitimately collapse: the
    /// shipped corpus has `de` "Standard" for both "default" and
    /// "Default", `ko` "고정" for "Make sticky"/"Rigid"/"Sticky".
    /// Four must pass.
    @Test(
        "plain-word collapses pass under the limit, fail at it",
        arguments: [(4, true), (5, false), (7, false)]
    )
    func plainCollapseLimit(count: Int, passes: Bool) throws {
        var english: [String: String] = [:]
        var catalog: [String: String] = [:]
        for index in 0..<count {
            english["a.\(index)"] = "Synonym\(index)"
            catalog["a.\(index)"] = "Standard"
        }
        let result = try CollapseFixture.check(
            english: english,
            catalog: catalog
        )
        #expect((result.status == 0) == passes)
    }

    /// A key the current code no longer defines has no English to
    /// be "unrelated" to, so it must not drag an otherwise fine
    /// value into a collapse.
    @Test("orphan keys are not counted")
    func orphanKeysAreNotCounted() throws {
        var catalog: [String: String] = ["a.real": "Standard"]
        for index in 0..<6 {
            catalog["a.orphan\(index)"] = "Standard"
        }
        let result = try CollapseFixture.check(
            english: ["a.real": "Default"],
            catalog: catalog
        )
        #expect(result.status == 0)
    }
}

/// Runs the real `scripts/extract-keys --check` over one generated
/// catalog. A third small fixture rather than a shared harness,
/// on the terms `.claude/rules/tests.md` sets for the env-var
/// scoped `extract-keys` suites.
private enum CollapseFixture {
    static func check(
        english: [String: String],
        catalog: [String: String]
    ) throws -> ScriptRun {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-collapse-guard-\(UUID().uuidString)"
            )
        let sources = base.appendingPathComponent("Sources")
        let locales = base.appendingPathComponent("Locales")
        defer { try? FileManager.default.removeItem(at: base) }
        for directory in [sources, locales] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        let calls = english.sorted { $0.key < $1.key }
            .map { "let _ = L(\"\($0.key)\", \"\($0.value)\")" }
            .joined(separator: "\n")
        try calls.write(
            to: sources.appendingPathComponent("Fixture.swift"),
            atomically: true,
            encoding: .utf8
        )
        let script = scriptFixtureRepoRoot()
            .appendingPathComponent("scripts/extract-keys")
        // Inherit the real environment and override the two keys,
        // rather than replacing it. A two-entry environment drops
        // PATH, so `/usr/bin/env python3` fell back to the system
        // 3.9 — a different interpreter from the one
        // `scripts/lint.sh` and CI use, which quietly made the
        // suite the only thing pinning 3.9 compatibility.
        var environment = ProcessInfo.processInfo.environment
        environment["KIWIDESK_EXTRACT_SOURCES"] = sources.path
        environment["KIWIDESK_EXTRACT_LOCALES"] = locales.path
        try runPythonScript(
            at: script,
            arguments: [],
            environment: environment
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(catalog).write(
            to: locales.appendingPathComponent("it.json")
        )
        return try runPythonScript(
            at: script,
            arguments: ["--check"],
            environment: environment
        )
    }
}
