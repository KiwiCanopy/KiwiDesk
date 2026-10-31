import Foundation
import Testing

/// CI's instruction lane (#2712): a change confined to `.claude/`
/// and `AGENTS.md` runs lint and the suites that read those paths,
/// not the whole suite. A reader missing from
/// `.github/ci-instruction-readers.txt` is the fail-open the lane
/// must not have, so the list is held to the tree both ways.
///
/// **A reader is a test file whose comment-free source spells a
/// `".claude"` / `".claude/…"` or `"AGENTS.md"` literal.** What
/// this cannot see is CiPathFilterTests' residue, one level over:
/// a path assembled from components none of which is `.claude`,
/// and a path a spawned `scripts/` tool reads on a test's behalf.
/// No script under `scripts/` reads `.claude/` outside its
/// comments today; one that starts to, and a suite running it,
/// is review's.
@Suite("CI instruction lane (#2712)")
struct CiInstructionLaneTests {
    /// Test files that spell a reader literal and read nothing,
    /// keyed by the path relative to `Tests/` — the one copy of
    /// who is exempt.
    static let exempt: [String: String] = [
        "KiwiDeskCoreTests/BarPeekContentTests.swift":
            "\"AGENTS.md\" is a window-title fixture"
    ]

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
            #""(\.claude(/[^"]*)?|AGENTS\.md)""#
        )
    }
    private static var topLevelType: Regex<AnyRegexOutput> {
        try! Regex(
            #"(?m)^(?:@MainActor\s+)?(?:final\s+)?"#
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
            readers.formUnion(types(in: text))
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
        #expect(
            list.subtracting(readers).isEmpty,
            "listed but reading nothing: \(list.subtracting(readers).sorted())"
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
        #expect(pattern == "\\.(\(list.sorted().joined(separator: "|")))/")
        let regex = try Regex(pattern)
        #expect(
            "KiwiDeskCoreTests.RuleCitationTests/citations()"
                .contains(regex)
        )
        #expect(!"KiwiDeskCoreTests.ExecTests/x()".contains(regex))
    }

    @Test("ci.yml picks the lane in the changes job and swaps the tests")
    func workflowRunsTheLane() throws {
        let yaml = try workflowSource("ci.yml")
        let changes = try #require(
            CiPathFilterTests.jobBlock("changes", in: yaml)
        )
        #expect(changes.contains("light: ${{ steps.filter.outputs.light }}"))
        #expect(changes.contains(".claude/*|AGENTS.md)"))
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
            readers.contains("--filter \"$(scripts/ci-instruction-filter)\"")
        )
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
            for path in [".claude/rules/x.md", "AGENTS.md"] {
                #expect(
                    !(entry == path || path.hasPrefix(prefix)),
                    "\(entry) would skip the lane for \(path)"
                )
            }
        }
    }
}
