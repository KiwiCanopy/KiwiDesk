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
/// Three things are checked, in the order they would bite:
///
/// 1. The `push:` and `pull_request:` lists are identical. The
///    Actions parser rejects YAML anchors, so the list is
///    hand-mirrored and drift would filter the two events
///    differently — a change tested pre-merge and skipped after,
///    or the reverse (parity-tests.md).
/// 2. No ignored path is read by anything under `Tests/`.
/// 3. The build and lint inputs are never ignored. This is the
///    clause a test-only audit misses: nothing in `Tests/` reads
///    `Package.swift`, `.swift-format` or `.swiftlint.yml`, and
///    ignoring any of them would skip CI for a change that alters
///    what compiles or what lint enforces.
///
/// **What this cannot see.** A path assembled from a variable
/// rather than written as a literal, and a path read only by a
/// `scripts/` tool the suite shells out to. Check (3) is a
/// hand-listed floor for the same reason — the build's inputs
/// cannot be derived from `Tests/`, so they are named here, and
/// naming them is itself a thing to keep current.
@Suite("CI path filter")
struct CiPathFilterTests {
    /// Paths whose change must always run CI, whatever else is
    /// true. Not derivable from `Tests/` — nothing there reads
    /// them — so they are enumerated, and each is the input to a
    /// step the job runs.
    static let neverIgnorable = [
        "Package.swift",  // defines what is built at all
        "Package.resolved",  // pins the dependency graph
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
    /// `site/`. Add an entry only after confirming the same thing,
    /// and name the file, so a second use elsewhere still fires.
    static let allowed = ["site": "ScriptFixture.swift"]

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }

    private var workflow: String {
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
        #expect(lists.count == 2, "found \(lists.count) lists, want 2")
        #expect(
            lists.first != [],
            "a paths-ignore list parsed as empty"
        )
        #expect(lists.first == lists.last, "the two lists differ")
    }

    @Test("No ignored path is read by the test suite")
    func ignoredPathsAreUnread() throws {
        let ignored = try Self.ignoreLists(workflow).first ?? []
        try #require(!ignored.isEmpty, "no paths-ignore entries")
        let sources = try testSources()
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
            // says nothing: tests read `.github/workflows/
            // release.yml` while `.github/workflows/site.yml` is
            // ignored, so flagging every `.github` would be noise.
            let wholeDirectory = !trimmed.contains("/")
            for (name, text) in sources {
                if let exempt = Self.allowed[trimmed],
                    name.hasSuffix(exempt)
                {
                    continue
                }
                let hit =
                    text.contains("\"\(prefix)")
                    || (wholeDirectory && text.contains("\"\(trimmed)\""))
                if hit { violations.append("\(name) reads \(entry)") }
            }
        }
        #expect(
            violations.isEmpty,
            "paths-ignore hides a path the suite reads: \(violations)"
        )
    }

    @Test("Build and lint inputs are never ignored")
    func buildInputsStayWatched() throws {
        let ignored = try Self.ignoreLists(workflow).first ?? []
        try #require(!ignored.isEmpty, "no paths-ignore entries")
        var violations: [String] = []
        for entry in ignored {
            let prefix = entry.replacingOccurrences(of: "**", with: "")
            for input in Self.neverIgnorable
            where input == entry || input.hasPrefix(prefix)
                || prefix.hasPrefix(input)
            {
                violations.append("\(entry) covers \(input)")
            }
        }
        #expect(
            violations.isEmpty,
            "paths-ignore covers a build/lint input: \(violations)"
        )
    }

    /// Every `.swift` under `Tests/`, as (relative name, text).
    private func testSources() throws -> [(String, String)] {
        let tests = repoRoot.appendingPathComponent("Tests")
        var out: [(String, String)] = []
        let walker = FileManager.default.enumerator(atPath: tests.path)
        let own = (#filePath as NSString).lastPathComponent
        while let entry = walker?.nextObject() as? String {
            guard entry.hasSuffix(".swift") else { continue }
            // This file names ignored paths as data — its `allowed`
            // map and its doc comment — so scanning it would report
            // the guard against itself. It reads only `ci.yml` and
            // `Tests/`, neither of which is ignorable.
            guard !entry.hasSuffix(own) else { continue }
            out.append(
                (
                    entry,
                    try String(
                        contentsOf: tests.appendingPathComponent(entry),
                        encoding: .utf8
                    )
                )
            )
        }
        return out
    }

    /// Each `paths-ignore:` block's quoted entries, in file order.
    static func ignoreLists(_ text: String) -> [[String]] {
        var out: [[String]] = []
        var current: [String]?
        for raw in text.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line == "paths-ignore:" {
                if let current { out.append(current) }
                current = []
                continue
            }
            guard current != nil else { continue }
            if line.hasPrefix("#") { continue }
            guard line.hasPrefix("- ") else {
                if !line.isEmpty {
                    out.append(current!)
                    current = nil
                }
                continue
            }
            let value =
                line
                .dropFirst(2)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            current?.append(value)
        }
        if let current { out.append(current) }
        return out
    }
}
