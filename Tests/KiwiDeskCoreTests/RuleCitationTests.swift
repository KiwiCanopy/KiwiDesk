import Foundation
import Testing

/// Every guard a rule file cites still exists (#614).
///
/// The convention in `rule-authoring.md` says an absolute claim
/// must name its enforcing guard inline. That trades one rot
/// vector for a smaller one: the citation itself goes stale on a
/// rename, and a rule pointing at a suite that no longer exists
/// is worse than a rule pointing at nothing — it reads as
/// guarded.
///
/// A regex cannot tell a state claim from an obligation (measured
/// on #614: the narrow vocabulary finds one paragraph, the broad
/// one flags 71 legitimate obligations), which is why the
/// meta-guard as originally filed was dropped. This is the part
/// that *is* mechanical: a citation either resolves or it does
/// not.
///
/// Symbols are matched by **declaration**, not by filename —
/// `DragCoordinatorTests` lives in `DragTests.swift`.
@Suite("Rule file citations")
struct RuleCitationTests {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }

    @Test("Every cited test suite is declared somewhere")
    func citedSuitesExist() throws {
        let declared = try declaredTestSymbols()
        var missing: [String] = []
        for (file, text) in try ruleDocuments() {
            for name in Self.backticked(text)
            where name.hasSuffix("Tests") && !name.contains("/") {
                // A SwiftPM *target* also ends in "Tests"
                // (`KiwiDeskCoreTests`) and is a directory, not a
                // declaration. Resolving either way counts.
                let asTarget =
                    repoRoot
                    .appendingPathComponent("Tests")
                    .appendingPathComponent(name)
                var isDirectory: ObjCBool = false
                let exists = FileManager.default.fileExists(
                    atPath: asTarget.path,
                    isDirectory: &isDirectory
                )
                if declared.contains(name) { continue }
                if exists, isDirectory.boolValue { continue }
                missing.append("\(file): \(name)")
            }
        }
        #expect(missing.isEmpty, "dangling citations: \(missing)")
    }

    @Test("Every cited script path exists")
    func citedScriptsExist() throws {
        var missing: [String] = []
        for (file, text) in try ruleDocuments() {
            for path in Self.backticked(text)
            where path.hasPrefix("scripts/") {
                // Trim a trailing glob or arg: `scripts/*key*`
                // and `scripts/drop-key <key>` are both cited.
                let bare = path.split(separator: " ")[0]
                // `scripts/*key*` is a glob and `scripts/…` is a
                // placeholder standing for "some script"; neither
                // names a file.
                guard !bare.contains("*"), !bare.contains("…")
                else { continue }
                let url = repoRoot.appendingPathComponent(
                    String(bare)
                )
                if !FileManager.default.fileExists(
                    atPath: url.path
                ) {
                    missing.append("\(file): \(bare)")
                }
            }
        }
        #expect(missing.isEmpty, "dangling scripts: \(missing)")
    }

    /// AGENTS.md plus every rule file — both are in scope for the
    /// convention, so both are in scope for its citations.
    private func ruleDocuments() throws -> [(String, String)] {
        var out: [(String, String)] = [
            (
                "AGENTS.md",
                try String(
                    contentsOf:
                        repoRoot
                        .appendingPathComponent("AGENTS.md"),
                    encoding: .utf8
                )
            )
        ]
        let rules =
            repoRoot
            .appendingPathComponent(".claude")
            .appendingPathComponent("rules")
        let names = try FileManager.default
            .contentsOfDirectory(atPath: rules.path)
            .filter { $0.hasSuffix(".md") }
            .sorted()
        // A fail-open guard is the thing this file exists to
        // prevent, so refuse to pass on an empty scan.
        #expect(names.count > 10, "only found \(names.count) rules")
        for name in names {
            out.append(
                (
                    name,
                    try String(
                        contentsOf:
                            rules
                            .appendingPathComponent(name),
                        encoding: .utf8
                    )
                )
            )
        }
        return out
    }

    /// Type and function names declared under `Tests/`.
    private func declaredTestSymbols() throws -> Set<String> {
        var found: Set<String> = []
        let tests = repoRoot.appendingPathComponent("Tests")
        let walker = FileManager.default.enumerator(
            atPath: tests.path
        )
        while let entry = walker?.nextObject() as? String {
            guard entry.hasSuffix(".swift") else { continue }
            let text = try String(
                contentsOf: tests.appendingPathComponent(entry),
                encoding: .utf8
            )
            for line in text.split(separator: "\n") {
                for keyword in ["struct ", "final class ", "class "]
                where line.contains(keyword) {
                    let tail =
                        line.components(
                            separatedBy: keyword
                        ).dropFirst().first ?? ""
                    let name = tail.prefix {
                        $0.isLetter || $0.isNumber || $0 == "_"
                    }
                    if !name.isEmpty {
                        found.insert(String(name))
                    }
                }
            }
        }
        return found
    }

    /// Every `backticked` span in a markdown document.
    private static func backticked(_ text: String) -> [String] {
        var out: [String] = []
        var inside = false
        var current = ""
        for character in text {
            if character == "`" {
                if inside, !current.isEmpty { out.append(current) }
                current = ""
                inside.toggle()
            } else if inside {
                current.append(character)
            }
        }
        return out
    }
}
