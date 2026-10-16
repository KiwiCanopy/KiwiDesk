import Foundation
import Testing

/// A float rule is read only through `FloatRules.parse` and spelled
/// only through `FloatRules.rule(app:title:)` (#2345): two readings
/// of its colon disagreeing is the whole defect, and it shipped in
/// three rounds — a case fold, a title split, a marker test. Every
/// colon split, colon test and `\(…):\(…)` spelling in either tree
/// is counted per file against a register naming why it stays, so
/// a new reader or writer of the grammar reds until it routes
/// through the seam or argues its place here.
@Suite("Float rule grammar seam")
struct FloatRuleGrammarSeamTests {
    private static let needles = [
        "split(separator: \":\"",
        "contains(\":\")",
        "):\\(",
    ]

    /// Files that may spell a needle, with the count each carries.
    private static let allowed: [String: Int] = [
        // The grammar's one reading and one spelling.
        "WindowRules.swift": 2,
        // A bundle-id ARGUMENT refused for carrying a colon, for
        // every app-rule family; no float rule is read.
        "KiwiCore+AppRuleCommands.swift": 1,
        // Not float rules: a fold row's id, a screen fingerprint,
        // the PATH split.
        "ShortcutFold.swift": 1,
        "DisplayModel.swift": 1,
        "ExecLauncher.swift": 1,
    ]

    @Test("the grammar is read and spelled only through FloatRules")
    func grammarHasOneHome() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        var counts: [String: Int] = [:]
        var scanned = 0
        for tree in ["Sources/KiwiDeskCore", "Sources/KiwiDesk"] {
            for url in try SourceScan.swiftSources(
                under: root.appendingPathComponent(tree)
            ) {
                scanned += 1
                let source = try SourceScan.strippedSource(at: url)
                let hits = Self.needles.reduce(0) {
                    $0 + source.components(separatedBy: $1).count - 1
                }
                if hits > 0 {
                    counts[url.lastPathComponent, default: 0] += hits
                }
            }
        }
        #expect(scanned >= 500, "scanned \(scanned) files")
        for (file, expected) in Self.allowed {
            #expect(
                counts[file] == expected,
                "\(file) spells the grammar \(counts[file] ?? 0)×"
            )
        }
        let strays = counts.keys.filter { Self.allowed[$0] == nil }
        #expect(
            strays.isEmpty,
            "float-rule grammar beside FloatRules: \(strays.sorted())"
        )
    }
}
