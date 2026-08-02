import Foundation
import Testing

/// `ci.yml`'s `paths-ignore` cannot switch off a suite silently.
///
/// The filter skips the whole CI job for a change touching only
/// listed paths. That is safe exactly while nothing the job does
/// reads them — and the failure mode is invisible: an entry added
/// in error does not break a build, it stops one from happening,
/// and a skipped workflow reports success by never reporting.
///
/// Five things are checked, in the order they would bite:
///
/// 1. The `push:` and `pull_request:` lists are identical, and are
///    the lists those two triggers own. The Actions parser rejects
///    YAML anchors, so the list is hand-mirrored, and drift would
///    filter the two events differently — a change tested
///    pre-merge and skipped after, or the reverse
///    (parity-tests.md).
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
///    `Package.swift`, `.swift-format` or `.swiftlint.yml`.
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
        ".swiftlint.yml",  // SwiftLint SPM build plugin
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
    static let allowed = [
        "site": "KiwiDeskCoreTests/ScriptFixture.swift"
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

    @Test("Both paths-ignore lists are identical")
    func listsMatch() throws {
        let lists = Self.ignoreLists(try workflow)
        // #require, not #expect: with no list parsed, every
        // comparison below is trivially true (nil != [], nil ==
        // nil) and only the count would red — pointing at the
        // wrong thing.
        try #require(
            lists.count == 2,
            "found \(lists.count) lists, want 2"
        )
        try #require(
            lists.map(\.trigger).sorted() == ["pull_request", "push"],
            "lists came from \(lists.map(\.trigger))"
        )
        let first = lists.first?.entries ?? []
        let last = lists.last?.entries ?? []
        let parsed = first.count
        try #require(parsed > 0, "a paths-ignore list parsed as empty")
        #expect(first == last, "the two lists differ")
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

    /// The ignore entries, refusing an empty parse.
    func entries() throws -> [String] {
        let ignored = Self.ignoreLists(try workflow).first?.entries ?? []
        try #require(!ignored.isEmpty, "no paths-ignore entries")
        return ignored
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
                let exempt = Self.allowed[trimmed] == name
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
