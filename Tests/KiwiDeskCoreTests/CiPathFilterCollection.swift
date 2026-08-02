import Foundation
import Testing

/// Collection and parsing for `CiPathFilterTests`.
///
/// Split out under the §2.1 ceiling, not because the halves are
/// independent: the assertions live next door and these exist only
/// to feed them. Nothing here asserts, so a change to a walk shows
/// up as a changed verdict there rather than as a green no-op.
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

    /// One YAML list value: either quote style, no trailing
    /// comment.
    ///
    /// Stripping only the outer double quotes leaves
    /// `- "docs/**"  # covered by site.yml` parsed as a path
    /// nothing can match — and because both hand-mirrored copies
    /// mangle identically, `listsMatch` stays green while checks
    /// (2), (3) and (4) quietly stop covering that entry.
    static func scalar(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespaces)
        if !value.hasPrefix("#"), let hash = value.range(of: " #") {
            value = String(value[..<hash.lowerBound])
        }
        value = value.trimmingCharacters(in: .whitespaces)
        for quote in ["\"", "'"] where value.hasPrefix(quote) {
            value = String(value.dropFirst())
            if value.hasSuffix(quote) { value = String(value.dropLast()) }
            break
        }
        return value
    }

    /// Each `paths-ignore:` block with the trigger that owns it.
    ///
    /// The trigger is recorded because two lists being equal says
    /// nothing about *which* events they filter — a block moved
    /// under a third trigger parses identically.
    static func ignoreLists(
        _ text: String
    ) -> [(trigger: String, entries: [String])] {
        var out: [(trigger: String, entries: [String])] = []
        var current: [String]?
        var trigger = ""
        var pending = ""
        for raw in text.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasSuffix(":"), !line.hasPrefix("-") {
                let key = String(line.dropLast())
                if key == "push" || key == "pull_request" {
                    pending = key
                }
            }
            if line == "paths-ignore:" {
                if let current { out.append((trigger, current)) }
                trigger = pending
                current = []
                continue
            }
            guard current != nil else { continue }
            if line.hasPrefix("#") { continue }
            guard line.hasPrefix("- ") else {
                if !line.isEmpty {
                    out.append((trigger, current!))
                    current = nil
                }
                continue
            }
            current?.append(Self.scalar(String(line.dropFirst(2))))
        }
        if let current { out.append((trigger, current)) }
        return out
    }
}
