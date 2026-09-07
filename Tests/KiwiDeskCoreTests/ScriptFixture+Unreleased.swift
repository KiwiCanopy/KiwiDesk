import Foundation

/// The docs-tree half of the script fixtures: lay out a corpus in
/// a throwaway directory, run `scripts/unreleased-strip` over it,
/// and hand back both the run and the pages as it left them
/// (#1232).
///
/// Shared by `UnreleasedStripTests` and
/// `UnreleasedStripGrammarTests`, which the §2.1 ceiling split.
/// `.claude/rules/tests.md`'s script-spawn bullet names this
/// file's family explicitly — it spawns and lays out a temp
/// tree, asserts nothing, and carries no state between calls.
///
/// Both halves are returned deliberately. Half the clauses in
/// those suites are about the CORPUS and half about the REPORT,
/// and a helper handing back only one of them would read the
/// other's failure as a pass.
///
/// **`pages` is RE-READ from disk, and that is the load-bearing
/// part.** Returning the fixture it was handed would make every
/// unchanged-page clause compare a page against itself.
/// `guard-prover` measured the reach (#1232): that mutation reds
/// the four clauses asserting a REWRITE and leaves the four
/// asserting no change green, so the re-read is guarded by the
/// positive half alone. A suite left with only negative clauses
/// would not notice it break.
struct SweptCorpus {
    let run: ScriptRun
    /// The pages as the sweep left them.
    let pages: [String: String]
}

/// Run the real script, in place, against a fixture tree.
///
/// `--docs` exists for these suites: the script's default target
/// is the repo's own `docs/`, and a test that swept it would
/// rewrite the very docs the change under test is adding.
func sweepFixtureCorpus(
    _ pages: [String: String],
    check: Bool = false
) throws -> SweptCorpus {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("unreleased-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    for (name, body) in pages {
        let page = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: page.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try body.write(to: page, atomically: true, encoding: .utf8)
    }
    let run = try runPythonScript(
        at: scriptFixtureRepoRoot()
            .appendingPathComponent("scripts/unreleased-strip"),
        arguments: ["--docs", root.path] + (check ? ["--check"] : [])
    )
    var after: [String: String] = [:]
    for name in pages.keys {
        after[name] =
            (try? String(
                contentsOf: root.appendingPathComponent(name),
                encoding: .utf8
            )) ?? ""
    }
    return SweptCorpus(run: run, pages: after)
}
