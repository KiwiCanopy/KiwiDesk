import Foundation
import Testing

/// Exercises the cross-language overlap guard (issue #95): two
/// locales sharing a suspicious number of byte-identical values,
/// the shape that caught ~360 entries of French sitting in
/// `it.json`. A script guard cannot see it — French and Italian
/// are Latin either way — and neither can a per-value check, so
/// this one needs whole catalogs and lives in its own suite.
///
/// Fixtures are generated here rather than read from the shipped
/// catalogs, so the guard's coverage never depends on the corpus
/// staying dirty.
@Suite("extract-keys overlap guard")
struct LocalizationOverlapGuardTests {
    /// Above `OVERLAP_FLOOR` (20) so the floor, not the 5% ratio,
    /// is what the fixtures are measured against — a 30-key
    /// catalog's 5% is 1, which would make every assertion here
    /// about a threshold the real corpus never uses.
    private static let keyCount = 30

    @Test("two languages sharing most values fail")
    func pastedFileFails() throws {
        let english = Self.english()
        let french = Self.translated("fr")
        let result = try OverlapFixture.check(
            english: english,
            catalogs: ["fr": french, "it": french]
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("fr.json and it.json"))
        #expect(result.stderr.contains("identical"))
    }

    @Test("distinct translations pass")
    func distinctTranslationsPass() throws {
        let result = try OverlapFixture.check(
            english: Self.english(),
            catalogs: [
                "fr": Self.translated("fr"),
                "it": Self.translated("it"),
            ]
        )
        #expect(result.status == 0)
    }

    /// Sibling languages really do coincide on short UI labels —
    /// `es`/`pt-BR` sit at 11 identical values with the corpus
    /// clean — so a handful of matches must stay under the floor.
    @Test("a few identical values stay under the floor")
    func fewMatchesPass() throws {
        var italian = Self.translated("it")
        let shared = Self.translated("fr")
        for key in Array(shared.keys.sorted().prefix(10)) {
            italian[key] = shared[key]
        }
        let result = try OverlapFixture.check(
            english: Self.english(),
            catalogs: ["fr": shared, "it": italian]
        )
        #expect(result.status == 0)
    }

    /// `zh-Hans` and `zh-Hant` are one language in two scripts and
    /// legitimately agree on a great deal, so pairs sharing a base
    /// language are skipped outright.
    @Test("same base language is exempt")
    func sameBaseLanguageIsExempt() throws {
        let chinese = Self.translated("zh")
        let result = try OverlapFixture.check(
            english: Self.english(),
            catalogs: ["zh-Hans": chinese, "zh-Hant": chinese]
        )
        #expect(result.status == 0)
    }

    /// Two locales agreeing on an *untranslated* string is the
    /// untranslated defect, not contamination, so English matches
    /// are never counted.
    @Test("values identical to English are not counted")
    func englishMatchesAreNotCounted() throws {
        let english = Self.english()
        let result = try OverlapFixture.check(
            english: english,
            catalogs: ["fr": english, "it": english]
        )
        #expect(result.status == 0)
    }

    /// A one-word label ("Lua", "Monitor") coincides innocently,
    /// so only values long enough to carry a phrase are counted.
    @Test("trivial one-word values are not counted")
    func trivialValuesAreNotCounted() throws {
        var english: [String: String] = [:]
        var shared: [String: String] = [:]
        for index in 0..<Self.keyCount {
            english["k.\(index)"] = "Word\(index)"
            shared["k.\(index)"] = "Mot\(index)"
        }
        let result = try OverlapFixture.check(
            english: english,
            catalogs: ["fr": shared, "it": shared]
        )
        #expect(result.status == 0)
    }

    /// The **ratio** branch, which the fixtures above never reach.
    /// At 810 shared keys the shipped corpus computes
    /// `max(20, 40) = 40`, so the 5% rule is what actually governs
    /// production while the floor is dead outside small catalogs —
    /// leaving `OVERLAP_RATIO` a free variable as far as a
    /// floor-only suite can tell. 440 keys puts the limit at 22.
    @Test(
        "past the floor, the 5% ratio governs",
        arguments: [(21, true), (25, false)]
    )
    func ratioGovernsLargeCatalogs(
        shared: Int,
        passes: Bool
    ) throws {
        let count = 440
        var english: [String: String] = [:]
        var french: [String: String] = [:]
        var italian: [String: String] = [:]
        for index in 0..<count {
            english["k.\(index)"] = "English phrase number \(index)"
            french["k.\(index)"] = "phrase fr numero \(index)"
            italian["k.\(index)"] =
                index < shared
                ? "phrase fr numero \(index)"
                : "phrase it numero \(index)"
        }
        let result = try OverlapFixture.check(
            english: english,
            catalogs: ["fr": french, "it": italian]
        )
        #expect((result.status == 0) == passes)
        if !passes {
            #expect(result.stderr.contains("identical"))
        }
    }

    private static func english() -> [String: String] {
        var map: [String: String] = [:]
        for index in 0..<keyCount {
            map["k.\(index)"] = "English phrase number \(index)"
        }
        return map
    }

    /// Non-trivial (well past 12 characters) and distinct per
    /// locale, so a pair only overlaps when a test makes it.
    private static func translated(
        _ locale: String
    ) -> [String: String] {
        var map: [String: String] = [:]
        for index in 0..<keyCount {
            map["k.\(index)"] = "phrase \(locale) numero \(index)"
        }
        return map
    }
}

/// Runs the real `scripts/extract-keys --check` against generated
/// catalogs, via the `KIWIDESK_EXTRACT_*` overrides.
///
/// Deliberately a second, smaller fixture rather than a shared
/// harness: `.claude/rules/tests.md` keeps per-file helpers the
/// convention and blesses this exact duplication (the env-var
/// scoped `extract-keys` suites lay out their own flat dirs). This
/// one writes *bulk* catalogs from dictionaries and needs no
/// `L(...)` escaping, so the overlap it has with the content
/// suite's fixture is the four lines that make a temp directory.
private enum OverlapFixture {
    static func check(
        english: [String: String],
        catalogs: [String: [String: String]]
    ) throws -> ScriptRun {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-overlap-guard-\(UUID().uuidString)"
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
        for (locale, catalog) in catalogs {
            try encoder.encode(catalog).write(
                to:
                    locales
                    .appendingPathComponent("\(locale).json")
            )
        }
        return try runPythonScript(
            at: script,
            arguments: ["--check"],
            environment: environment
        )
    }
}
