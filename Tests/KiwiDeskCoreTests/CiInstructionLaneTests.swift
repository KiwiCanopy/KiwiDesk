import Foundation
import Testing

/// CI's instruction lane (#2712): a change confined to `.claude/`
/// and `AGENTS.md` runs lint and the suites that read those paths,
/// not the whole suite. A reader missing from
/// `.github/ci-instruction-readers.txt` is the fail-open the lane
/// must not have, so the list is held to the tree both ways.
///
/// **A reader is a test file whose comment-free source spells a
/// one-line literal naming `.claude` or `AGENTS.md` as a path
/// component.** Every type such a file declares or extends must be
/// a suite the filter can run. What this cannot see is
/// CiPathFilterTests' residue, one level over: a path assembled
/// from components none of which is `.claude`, a path inside a
/// multi-line literal, a suite reaching a reader's helper with no
/// literal of its own, and a path a spawned `scripts/` tool reads
/// on a test's behalf. A suite of those shapes joins the list
/// through `consumers`, with its reason, in the change that makes
/// it one. The walk is its own rather than
/// `CiPathFilterTests.testSources()`, which skips that suite's own
/// file by design.
@Suite("CI instruction lane (#2712)")
struct CiInstructionLaneTests {
    /// Test files that spell a reader literal and read nothing,
    /// keyed by the path relative to `Tests/` — the one copy of
    /// who is exempt.
    static let exempt: [String: String] = [
        "KiwiDeskCoreTests/BarPeekContentTests.swift":
            "\"AGENTS.md\" is a window-title fixture"
    ]

    /// Suites the list carries though they spell no reader literal,
    /// each with what it reads — the one copy of who may.
    static let consumers: [String: String] = [:]

    private static let own = "KiwiDeskCoreTests/CiInstructionLaneTests.swift"

    private var repoRoot: URL { scriptFixtureRepoRoot() }

    /// Every `.swift` under `Tests/` but this one, `//` lines
    /// dropped, as (path relative to `Tests/`, text).
    private func sources() throws -> [(String, String)] {
        let tests = repoRoot.appendingPathComponent("Tests")
        var out: [(String, String)] = []
        let walker = FileManager.default.enumerator(atPath: tests.path)
        while let entry = walker?.nextObject() as? String {
            guard entry.hasSuffix(".swift"), entry != Self.own
            else { continue }
            let text = try String(
                contentsOf: tests.appendingPathComponent(entry),
                encoding: .utf8
            )
            let code = text.split(separator: "\n")
                .filter {
                    !$0.trimmingCharacters(in: .whitespaces)
                        .hasPrefix("//")
                }
                .joined(separator: "\n")
            out.append((entry, code))
        }
        try #require(out.count > 100, "the Tests/ walk came back short")
        return out
    }

    private static var readerLiteral: Regex<AnyRegexOutput> {
        try! Regex(
            #""([^"\n]*/)?(\.claude(/[^"\n]*)?|AGENTS\.md)""#
        )
    }
    private static var topLevelType: Regex<AnyRegexOutput> {
        try! Regex(
            #"(?m)^(?:@MainActor\s+)?(?:(?:file)?private\s+)?"#
                + #"(?:final\s+)?"#
                + #"(?:struct|class|enum|extension)\s+(\w+)"#
        )
    }
    private static var suiteType: Regex<AnyRegexOutput> {
        try! Regex(
            #"@Suite\([^\n]*\)\s*(?:@MainActor\s+)?struct\s+(\w+)"#
        )
    }

    /// The type names the listed file declares or extends.
    private func types(in text: String) -> Set<String> {
        Set(
            text.matches(of: Self.topLevelType).compactMap {
                $0.output[1].substring.map(String.init)
            }
        )
    }

    /// The suites the list names.
    private func listed() throws -> Set<String> {
        let text = try String(
            contentsOf: repoRoot.appendingPathComponent(
                ".github/ci-instruction-readers.txt"
            ),
            encoding: .utf8
        )
        let names = text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        try #require(!names.isEmpty, "the readers list is empty")
        return Set(names)
    }

    @Test("the readers list is exactly the suites that read .claude/")
    func listMatchesTheReaders() throws {
        let files = try sources()
        let suites = Set(
            files.flatMap { _, text in
                text.matches(of: Self.suiteType).compactMap {
                    $0.output[1].substring.map(String.init)
                }
            }
        )
        var readers: Set<String> = []
        for (path, text) in files
        where text.contains(Self.readerLiteral) && Self.exempt[path] == nil {
            // A literal in a free function names no suite at all.
            let declared = types(in: text)
            #expect(!declared.isEmpty, "\(path) reads, in no type")
            readers.formUnion(declared)
        }
        try #require(!readers.isEmpty, "no reader found at all")
        // A helper type reading the paths hides its consumers from
        // the filter, which matches suite names alone.
        #expect(
            readers.subtracting(suites).isEmpty,
            """
            not a suite, so the lane's filter cannot run it — \
            list its consumers instead: \
            \(readers.subtracting(suites).sorted())
            """
        )
        let list = try listed()
        #expect(
            readers.subtracting(list).isEmpty,
            """
            readers missing from the lane: \
            \(readers.subtracting(list).sorted())
            """
        )
        let named = readers.union(Self.consumers.keys)
        #expect(
            Set(Self.consumers.keys).isSubset(of: suites),
            "a consumer is no suite: \(Self.consumers.keys.sorted())"
        )
        #expect(
            list.subtracting(named).isEmpty,
            "listed but reading nothing: \(list.subtracting(named).sorted())"
        )
    }

    @Test("every exemption still spells the literal it excuses")
    func exemptionsAreLive() throws {
        let files = Dictionary(
            try sources(),
            uniquingKeysWith: { first, _ in first }
        )
        for path in Self.exempt.keys.sorted() {
            let text = try #require(files[path], "\(path) is gone")
            #expect(text.contains(Self.readerLiteral), "\(path)")
        }
    }

    @Test("the filter script names every listed suite")
    func filterNamesTheList() throws {
        let run = try spawn(
            "/bin/bash",
            ["scripts/ci-instruction-filter"],
            currentDirectory: repoRoot
        )
        try #require(run.status == 0, "\(run.stderr)")
        let pattern = run.stdout.trimmingCharacters(in: .newlines)
        let list = try listed()
        try #require(pattern.hasPrefix("\\.(") && pattern.hasSuffix(")/"))
        let body = pattern.dropFirst(3).dropLast(2)
        #expect(Set(body.split(separator: "|").map(String.init)) == list)
        let regex = try Regex(pattern)
        #expect(
            "KiwiDeskCoreTests.RuleCitationTests/citations()"
                .contains(regex)
        )
        #expect(!"KiwiDeskCoreTests.ExecTests/x()".contains(regex))
    }

    @Test("the filter script refuses an empty list and an unknown suite")
    func filterRefuses() throws {
        let dir = testTemporaryDirectory.appendingPathComponent(
            "ci-lane-\(UUID().uuidString)"
        )
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        for (name, text) in [
            ("empty", "# nothing\n\n"),
            ("unknown", "RuleCitationTests\nNoSuchSuiteTests\n"),
        ] {
            let list = dir.appendingPathComponent(name)
            try text.write(to: list, atomically: true, encoding: .utf8)
            let run = try spawn(
                "/bin/bash",
                ["scripts/ci-instruction-filter", list.path],
                currentDirectory: repoRoot
            )
            #expect(run.status != 0, "\(name) list was accepted")
            #expect(run.stdout.isEmpty, "\(name): \(run.stdout)")
        }
    }

    @Test("ci.yml picks the lane in the changes job and swaps the tests")
    func workflowRunsTheLane() throws {
        let yaml = try workflowSource("ci.yml")
        let changes = try #require(
            CiPathFilterTests.jobBlock("changes", in: yaml)
        )
        #expect(changes.contains("light: ${{ steps.filter.outputs.light }}"))
        // The lane's paths exactly: a wider arm puts paths on the
        // lane that no reader scan covers.
        let arms = changes.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasSuffix(")") && $0.contains(".claude") }
        #expect(arms == [".claude/*|AGENTS.md)"])
        #expect(
            changes.contains(
                "AGENTS.md)\n"
                    + "                  echo \"instruction file: $file\"\n"
                    + "                  light=true\n"
            )
        )
        // A push keeps the full run; renames name both ends.
        #expect(changes.contains("pull_request) lane=true ;;"))
        #expect(changes.contains("if [ \"$lane\" = true ]; then"))
        #expect(
            changes.components(separatedBy: "--name-only --no-renames")
                .count == 3
        )
        #expect(
            changes.contains("echo \"light=$light\" >> \"$GITHUB_OUTPUT\"")
        )
        // A path outside the lane clears it, or a mixed change
        // would run the readers alone.
        let decide = try workflowStep(
            "Decide whether the build jobs must run",
            in: yaml
        )
        let other = try #require(decide.range(of: "run=true\n"))
        #expect(
            decide[other.upperBound...].hasPrefix(
                "            light=false\n            break"
            )
        )
        for name in ["Test", "Test (ExecTests)"] {
            let step = try workflowStep(name, in: yaml)
            #expect(
                step.contains("if: needs.changes.outputs.light != 'true'"),
                "\(name) must run unless the lane was picked"
            )
        }
        let readers = try workflowStep("Instruction readers", in: yaml)
        #expect(readers.contains("if: needs.changes.outputs.light == 'true'"))
        #expect(
            readers.contains("filter=\"$(scripts/ci-instruction-filter)\"")
        )
        #expect(readers.contains("swift test --filter \"$filter\""))
        // The release build stays off the lane: nothing it builds
        // reads an instruction file.
        let release = CiPathFilterTests.jobGate("release-build", in: yaml)
        #expect(release?.contains("light") == false)
    }

    @Test("no ci-ignore entry swallows an instruction path")
    func instructionPathsAreNotIgnored() throws {
        let ignore = try String(
            contentsOf: CiPathFilterTests.ignoreFile(under: repoRoot),
            encoding: .utf8
        )
        let entries = ignore.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        for entry in entries {
            let prefix = entry.replacingOccurrences(of: "**", with: "")
            for path in [".claude/", "AGENTS.md"] {
                #expect(
                    !(entry == path || path.hasPrefix(prefix)
                        || prefix.hasPrefix(path)),
                    "\(entry) would skip the lane for \(path)"
                )
            }
        }
    }
}
