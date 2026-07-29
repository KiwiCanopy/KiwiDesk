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
///
/// **What it deliberately does not check:** a bare test *function*
/// name. `rule-authoring.md` allows one, but nothing about the
/// shape of `aFrozenSpringIsStillRescued` separates it from the
/// production symbols these files cite on every other line, so
/// checking them would mean flagging `retarget` and
/// `maxStableStep` too. The rule file therefore asks for the
/// suite name alongside; that half is checked here.
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
        var seen = 0
        for (file, text) in try ruleDocuments() {
            for name in Self.backticked(text)
            where name.hasSuffix("Tests") && !name.contains("/") {
                seen += 1
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
        // A total-scan canary, for a walk that finds nothing.
        #expect(seen > 20, "only saw \(seen) suite citations")
    }

    @Test("No document can invert the scanner")
    func backticksAreBalanced() throws {
        // The fail-open path, and it is specific to how
        // `backticked` works: it toggles on every backtick, so
        // ONE unbalanced backtick inverts inside/outside for the
        // rest of *that document* and every real citation after
        // it is silently skipped. The count canary above does not
        // reach this — the other fifteen files still supply
        // plenty of citations — so parity has to be checked per
        // document. A fenced code block keeps parity (three
        // backticks twice is an even number of toggles) but is
        // NOT otherwise handled: its whole body is harvested as
        // one span, and it matches neither predicate only
        // because a fence body ends in a newline. Inert by
        // accident, not by design.
        for (file, text) in try ruleDocuments() {
            let ticks = text.filter { $0 == "`" }.count
            let why =
                "\(file) has \(ticks) backticks, so the scan "
                + "silently stops seeing citations partway"
            #expect(ticks % 2 == 0, "\(why)")
        }
    }

    @Test("Every cited script or workflow path exists")
    func citedScriptsExist() throws {
        var missing: [String] = []
        var seen = 0
        for (file, text) in try ruleDocuments() {
            for raw in Self.backticked(text) {
                // `./scripts/build-app.sh` is how AGENTS.md and
                // packaging-and-release.md cite these, so the
                // prefix test has to see past the `./` — six live
                // citations were invisible without this, one of
                // them added by the commit that shipped me.
                let path =
                    raw.hasPrefix("./") ? String(raw.dropFirst(2)) : raw
                // `.github/workflows/` joins `scripts/` as a
                // resolvable shape (#32). A rule now cites the
                // release workflow as an enforcing guard, and it
                // is the most consequential one in the tree that
                // no local test can execute — so a citation
                // rotting to a file that no longer exists would
                // leave the rule reading as guarded by nothing.
                guard
                    path.hasPrefix("scripts/")
                        || path.hasPrefix(".github/workflows/")
                else { continue }
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
                seen += 1
                if !FileManager.default.fileExists(
                    atPath: url.path
                ) {
                    missing.append("\(file): \(bare)")
                }
            }
        }
        #expect(missing.isEmpty, "dangling paths: \(missing)")
        #expect(seen > 10, "only saw \(seen) path citations")
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
        #expect(names.count >= 15, "only found \(names.count) rules")
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
                // Declarations only. Substring matching over raw
                // lines also fires on `/// The struct FooTests
                // covers…`, so a rename that leaves any prose
                // mention behind would keep its citation
                // resolving.
                let bare = line.drop { $0 == " " }
                guard !bare.hasPrefix("//") else { continue }
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
