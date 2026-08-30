import Foundation
import Testing

/// `scripts/merge-keys` refuses to run while any
/// `KIWIDESK_EXTRACT_*` is set to a non-empty value, in both
/// modes (issue #1107).
///
/// Before the refusal it honoured exactly ONE of the family —
/// `KIWIDESK_EXTRACT_WORKSHEETS` — while its catalog directory
/// stayed `__file__`-derived, so a harness that believed it was
/// sandboxed read redirected worksheets, rewrote the developer's
/// REAL catalogs, and unlinked the worksheet (the only copy of
/// the work). The refusal is over the whole family, the same
/// shape as `site_override_conflict`: a member `merge-keys`
/// never reads (`KIWIDESK_EXTRACT_SOURCES`) still signals a
/// caller who believes the run is redirected.
///
/// Split from `MergeKeysBehaviourTests`, which sits at the
/// 350-line ceiling (AGENTS.md §2.1; tests.md "split suites
/// early"). Per-file private helpers are the convention, so the
/// small fixture/run pair below is duplicated deliberately.
///
/// Each run here sets an override explicitly — the documented
/// one case for `runRepoScript`'s `environment` parameter, since
/// the harness otherwise clears the family. The paths point into
/// the fixture so that even a regression that honours them again
/// cannot write outside the throwaway tree.
@Suite("merge-keys override refusal")
struct MergeKeysOverrideRefusalTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    /// A fully mergeable fixture, so the override is the ONLY
    /// reason a refusing run refuses.
    private func fixture() throws -> RepoShapedFixture {
        try makeRepoShapedFixture(
            prefix: "kiwi-merge-override",
            locales: [
                "en.json": #"{"a.key": "Hello"}"#,
                "de.json": #"{}"#,
                "missing_de.json": #"""
                {"a.key":
                  {"source": "Hello", "translation": "Hallo"}}
                """#,
            ]
        )
    }

    @Test(
        "any live override refuses before a path is touched",
        arguments: [
            "KIWIDESK_EXTRACT_LOCALES",
            "KIWIDESK_EXTRACT_WORKSHEETS",
            "KIWIDESK_EXTRACT_SOURCES",
        ]
    )
    func liveOverrideRefuses(variable: String) throws {
        let fx = try fixture()
        defer { fx.cleanup() }

        let redirect = fx.root
            .appendingPathComponent("redirected").path
        let run = try runRepoScript(
            "merge-keys",
            arguments: ["de"],
            in: fx,
            repoRoot: repoRoot,
            environment: [variable: redirect]
        )
        #expect(run.status == 1)
        #expect(run.stderr.contains(variable))
        #expect(run.stderr.contains("honours no override"))
        // The refusal precedes every path read: the catalog is
        // unwritten and the worksheet — the only copy of the
        // translator's work — is not unlinked.
        #expect(try fx.decodeLocale("de.json").isEmpty)
        #expect(fx.worksheetExists("missing_de.json"))
    }

    /// `--site` was refused under an override before #1107 too
    /// (`site_override_conflict`); the family-wide predicate
    /// subsumes that path, so the case pins it is still closed.
    @Test("--site under a live override still refuses")
    func siteModeStillRefuses() throws {
        let fx = try fixture()
        defer { fx.cleanup() }

        let redirect = fx.root
            .appendingPathComponent("redirected").path
        let run = try runRepoScript(
            "merge-keys",
            arguments: ["--site", "de"],
            in: fx,
            repoRoot: repoRoot,
            environment: [
                "KIWIDESK_EXTRACT_LOCALES": redirect
            ]
        )
        #expect(run.status == 1)
        #expect(
            run.stderr.contains("KIWIDESK_EXTRACT_LOCALES")
        )
    }

    /// `VAR=` exported is "unset" (`locale_paths._override`'s
    /// rule): a shell that cleared the variable by emptying it
    /// must not be refused, or the refusal starts costing runs
    /// the override never endangered.
    @Test("an override set to the empty string does not refuse")
    func emptyValueMerges() throws {
        let fx = try fixture()
        defer { fx.cleanup() }

        let run = try runRepoScript(
            "merge-keys",
            arguments: ["de"],
            in: fx,
            repoRoot: repoRoot,
            environment: ["KIWIDESK_EXTRACT_LOCALES": ""]
        )
        #expect(run.status == 0)
        let merged = try fx.decodeLocale("de.json")
        #expect(merged["a.key"] == "Hallo")
        #expect(!fx.worksheetExists("missing_de.json"))
    }
}
