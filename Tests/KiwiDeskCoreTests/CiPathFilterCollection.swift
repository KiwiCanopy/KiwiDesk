import Foundation
import Testing

/// Collection and parsing for `CiPathFilterTests`.
///
/// Split out under the §2.1 ceiling, not because the halves are
/// independent: most of the assertions live next door and these
/// exist to feed them.
///
/// **It is not assertion-free**, and the sentence here used to say
/// it was (#661) — a reader trusting that would move code
/// carrying a live check. Three things assert in this file:
/// `buildInputsStayWatched` is a whole `@Test`; `ruleFiles()`
/// reports an empty directory; `entries()` refuses an empty parse
/// outright, with `try #require`.
///
/// The last two are deliberate *floors* rather than strays. A walk
/// that half-failed still returns a list, and every check next
/// door is a search for violations in that list — so an empty or
/// truncated walk reports a clean verdict instead of an error.
/// Failing at the source is what makes the silence next door mean
/// something.
extension CiPathFilterTests {
    /// Every `.claude/rules/*.md`, as (name, text).
    func ruleFiles() throws -> [(String, String)] {
        let root =
            repoRoot
            .appendingPathComponent(".claude")
            .appendingPathComponent("rules")
        let names = try FileManager.default
            .contentsOfDirectory(atPath: root.path)
            .filter { $0.hasSuffix(".md") }
            .sorted()
        #expect(!names.isEmpty, "no rule files found")
        return try names.map { name in
            (
                name,
                try String(
                    contentsOf: root.appendingPathComponent(name),
                    encoding: .utf8
                )
            )
        }
    }

    @Test("Build and lint inputs are never ignored")
    func buildInputsStayWatched() throws {
        let ignored = try entries()
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
    func testSources() throws -> [(String, String)] {
        let tests = repoRoot.appendingPathComponent("Tests")
        var out: [(String, String)] = []
        let walker = FileManager.default.enumerator(atPath: tests.path)
        let own = "KiwiDeskCoreTests/CiPathFilterTests.swift"
        while let entry = walker?.nextObject() as? String {
            guard entry.hasSuffix(".swift") else { continue }
            // This file names ignored paths as data — its `allowed`
            // map and its doc comment — so scanning it would report
            // the guard against itself. It reads only `ci.yml` and
            // `Tests/`, neither of which is ignorable.
            guard entry != own else { continue }
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

    /// The ignore entries, refusing an empty parse.
    ///
    /// One authority: `.github/ci-ignore.txt`. The old shape kept
    /// the list twice inside `ci.yml` (the Actions parser rejects
    /// YAML anchors) and needed a parity check to hold the copies
    /// equal. Moving it out deleted that whole class.
    func entries() throws -> [String] {
        let text = try String(
            contentsOf: Self.ignoreFile(under: repoRoot),
            encoding: .utf8
        )
        let parsed = text.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        try #require(!parsed.isEmpty, "no ci-ignore entries")
        return parsed
    }

    /// One job's YAML block: its `  name:` line through the line
    /// before the next key at the same indent.
    static func jobBlock(_ name: String, in yaml: String) -> String? {
        let lines = yaml.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        guard let start = lines.firstIndex(where: { $0 == "  \(name):" })
        else { return nil }
        var end = lines.index(after: start)
        while end < lines.endIndex {
            let line = lines[end]
            let isSibling =
                line.hasPrefix("  ") && !line.hasPrefix("   ")
                && line.hasSuffix(":")
            if isSibling { break }
            end = lines.index(after: end)
        }
        return lines[start..<end].joined(separator: "\n")
    }

    static func ignoreFile(under root: URL) -> URL {
        root
            .appendingPathComponent(".github")
            .appendingPathComponent("ci-ignore.txt")
    }
}
