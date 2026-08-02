import Foundation
import Testing

/// `.github/ci-ignore.txt` cannot switch off a suite silently.
///
/// The `changes` job in `ci.yml` reads that list and gates the two
/// macOS jobs on it. A wrong entry does not break a build, it stops
/// one from happening — and a job that never ran reports nothing to
/// contradict.
///
/// Five things are checked, in the order they would bite:
///
/// 1. `ci.yml` still reads the list and still gates on it, and has
///    not gone back to a trigger-level `paths-ignore`. That older
///    shape saved the same minutes but skipped the *workflow*, and
///    a workflow that does not run reports no check at all — which
///    deadlocks a required status check, unlike a job skipped by
///    `if:`, which satisfies one (#487).
/// 2. Every entry is an exact path or `dir/**`. The other checks
///    are prefix relations over plain strings, so `*` and `?` are
///    ordinary characters to them: `Package.*` would ignore
///    `Package.swift` while matching nothing any of them compares
///    against. Constraining the shape is what makes the rest sound.
/// 3. No ignored path appears as a literal under `Tests/`.
/// 4. No ignored path is *pinned* by a rule file's `paths:` block.
///    The suite reads those from data rather than from source, so
///    check (3) is blind to them by construction — which is how
///    `docs/**` reached review: no test opens a docs page, but
///    `localization.md` pins two, and `InstructionPinTests`
///    resolves every such pin.
/// 5. The build and lint inputs are never ignored — the clause a
///    test-only audit misses, since nothing in `Tests/` reads
///    `Package.swift` or `.swift-format`.
///
/// **What this cannot see**, stated plainly because check (3)
/// promises more than it delivers: a path written as
/// `.appendingPathComponent` chains is invisible unless its first
/// component is a whole ignored directory, and that is the repo's
/// normal idiom — `VerifyGateParityTests` assembles
/// `.github/workflows/release.yml` from three separate literals,
/// so ignoring that exact path would pass every check here. Also
/// invisible: a path reached only by a `scripts/` tool the suite
/// shells out to, and a path reached case-insensitively (`Docs`
/// resolves `docs/` on APFS). Check (5) is a hand-listed floor for
/// the same reason — the build's inputs cannot be derived from
/// `Tests/`.
///
/// The practical consequence: a *multi-component* entry earns far
/// less protection than a whole-directory one. Prefer ignoring a
/// whole top-level directory, and treat a deep path as needing
/// human argument rather than a green suite.
@Suite("CI path filter")
struct CiPathFilterTests {
    /// Paths whose change must always run CI, whatever else is
    /// true. Not derivable from `Tests/` — nothing there reads
    /// them — so they are enumerated, and each is the input to a
    /// step the job runs.
    static let neverIgnorable = [
        "Package.swift",  // defines what is built at all
        ".swift-format",  // scripts/lint.sh --configuration
        "Sources",
        "Tests",
        "Vendor",
        "scripts",
        ".github/workflows/ci.yml",
    ]

    /// The one copy of who is exempt from the component match
    /// (the `allowed`-map idiom, AGENTS.md §5).
    ///
    /// A bare component literal cannot tell a repo-rooted path from
    /// a same-named directory built somewhere else. `ScriptFixture`
    /// assembles a `site` directory inside a **temp** tree for the
    /// `extract-keys --site` fixtures; it never reaches the repo's
    /// `site/`. Add an entry only after confirming the same thing.
    ///
    /// Keyed by the path relative to `Tests/`, not by filename: a
    /// same-named file in the other target would otherwise inherit
    /// an exemption nobody granted it.
    ///
    /// A *set* per component, not one file: the fixture's `site`
    /// tree outgrew a single file when the worksheet accessors
    /// split off at the size ceiling, and both halves build the
    /// same temp component. Each member still earns its own
    /// confirmation and is checked individually below — widening
    /// the shape is not widening the exemption.
    static let allowed: [String: Set<String>] = [
        "site": [
            "KiwiDeskCoreTests/ScriptFixture.swift",
            "KiwiDeskCoreTests/ScriptFixture+Worksheets.swift",
        ]
    ]

    var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }

    var workflow: String {
        get throws {
            try String(
                contentsOf:
                    repoRoot
                    .appendingPathComponent(".github")
                    .appendingPathComponent("workflows")
                    .appendingPathComponent("ci.yml"),
                encoding: .utf8
            )
        }
    }

    @Test("ci.yml still consults the list, and gates on it")
    func workflowConsultsTheList() throws {
        let yaml = try workflow
        // Without this the whole mechanism is decorative: the file
        // parses, every other check passes over it, and the jobs
        // run unconditionally — or worse, the filter moves back to
        // a trigger-level `paths-ignore`, whose skipped workflow
        // reports no check run and deadlocks a required check.
        #expect(
            yaml.contains(".github/ci-ignore.txt"),
            "ci.yml no longer reads the ignore list"
        )
        // The key, not the word: the comment above the triggers
        // explains why this shape was abandoned, and naming it
        // there must not read as using it.
        let usesTriggerFilter =
            yaml
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .contains { $0.hasPrefix("paths-ignore:") }
        #expect(
            !usesTriggerFilter,
            """
            ci.yml filters at the trigger again — a filtered-out \
            workflow never reports, so a required check waits \
            forever (#487, scripts/protect-main.sh)
            """
        )
        // Per job, not over the whole file. A whole-file
        // `contains` is satisfied by one job keeping its gate
        // while the other loses it — which is exactly the mutation
        // that has to red, and did not until this was split.
        for job in ["build-lint-test", "release-build"] {
            let block = Self.jobBlock(job, in: yaml)
            #expect(
                block?.contains("needs: changes") == true,
                "\(job) does not depend on the changes job"
            )
            #expect(
                block?.contains("if: needs.changes.outputs.run == 'true'")
                    == true,
                "\(job) is not gated on the changes outcome"
            )
        }
    }

    @Test("Every exemption is still load-bearing")
    func exemptionsAreLive() throws {
        // The idiom's other half, which both precedents carry
        // (`VisibleBoundsRoutingTests`, `BatchSizingRoutingTests`):
        // an exemption that outlives its reason silently widens the
        // hole it was cut for. Assert each entry still describes a
        // file that still contains the component it excuses.
        let sources = try testSources()
        for (component, files) in Self.allowed {
            for file in files.sorted() {
                let source = sources.first { $0.0 == file }
                let text = try #require(
                    source?.1,
                    "exempted file \(file) is gone"
                )
                #expect(
                    text.contains("\"\(component)\""),
                    """
                    \(file) no longer builds a \(component) \
                    component
                    """
                )
            }
        }
    }

    @Test("Every entry is an exact path or a whole subtree")
    func entryShapesArePrefixSafe() throws {
        let ignored = try entries()
        // Every other check here is a prefix relation over plain
        // strings, so `*` and `?` are ordinary characters to them:
        // `Package.*` ignores Package.swift while matching nothing
        // any check compares against, and `*.md` sweeps AGENTS.md
        // in past all of them. Rather than teach four checks to
        // glob, constrain the shape so prefix logic is sound.
        var malformed: [String] = []
        for entry in ignored {
            let body =
                entry.hasSuffix("/**")
                ? String(entry.dropLast(3)) : entry
            if body.contains("*") || body.contains("?") {
                malformed.append(entry)
            }
        }
        #expect(
            malformed.isEmpty,
            """
            an entry must be an exact path or `dir/**`; these hide \
            from every prefix check: \(malformed)
            """
        )
    }

    @Test("No ignored path is read by the test suite")
    func ignoredPathsAreUnread() throws {
        let ignored = try entries()
        let sources = try testSources()
        // A count alone is a total-failure canary: the margin over
        // the tree is wide enough that most of the walk could
        // vanish and still clear it. Requiring both targets catches
        // a walk that half-failed, which a count cannot.
        let targets = Set(
            sources.compactMap { $0.0.split(separator: "/").first }
        )
        try #require(
            targets.count >= 2,
            "scan covered only \(targets.sorted())"
        )
        try #require(
            sources.count > 100,
            "only scanned \(sources.count) test files"
        )

        var violations: [String] = []
        for entry in ignored {
            let prefix = entry.replacingOccurrences(of: "**", with: "")
            let trimmed =
                prefix.hasSuffix("/")
                ? String(prefix.dropLast()) : prefix
            // A whole top-level directory is matched by its bare
            // component, because that is how the suite actually
            // writes these — `.appendingPathComponent("assets")`,
            // never `"assets/logo.svg"`. Matching only the rooted
            // form would give this guard nothing to catch.
            //
            // A deeper entry gets prefix matching only. Its head
            // says nothing — tests read some paths under `.github`
            // while others there are ignorable, so flagging every
            // `.github` would be noise. That weakness is why the
            // doc comment tells you a deep entry is barely guarded.
            let wholeDirectory = !trimmed.contains("/")
            for (name, text) in sources {
                // The exemption covers ONLY the bare-component
                // needle it was granted for. A rooted `"site/`
                // literal in the same file is a real read and must
                // still fire.
                let exempt =
                    Self.allowed[trimmed]?.contains(name) == true
                let hit =
                    text.contains("\"\(prefix)")
                    || (wholeDirectory && !exempt
                        && text.contains("\"\(trimmed)\""))
                if hit { violations.append("\(name) reads \(entry)") }
            }
        }
        #expect(
            violations.isEmpty,
            "paths-ignore hides a path the suite reads: \(violations)"
        )
    }

    @Test("No ignored path is pinned by a rule file")
    func ignoredPathsArentRulePins() throws {
        let ignored = try entries()

        // The suite reads these from *data*, not from a source
        // literal: `InstructionPinTests` resolves every non-glob
        // `paths:` entry in every rule file, so each is a path a
        // change can break — and check (2) cannot see it, because
        // no `.swift` file contains the string.
        //
        // This is what let `docs/**` through review: nothing opens
        // a docs page, but `localization.md` pins two of them.
        var pins: [String] = []
        for (_, text) in try ruleFiles() {
            pins += InstructionPinTests.pathEntries(text)
                .filter { !$0.contains("*") && !$0.contains("?") }
        }
        try #require(pins.count > 5, "only found \(pins.count) pins")

        var violations: [String] = []
        for entry in ignored {
            let prefix = entry.replacingOccurrences(of: "**", with: "")
            for pin in pins where pin == entry || pin.hasPrefix(prefix) {
                violations.append("\(entry) covers the pin \(pin)")
            }
        }
        #expect(
            violations.isEmpty,
            "paths-ignore hides a rule-file pin: \(violations)"
        )
    }
}
