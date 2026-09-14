import Foundation
import Testing

/// The empty-display heal has two homes and one ledger (#1175):
/// `healEmptyDisplays` is reached from the tail of the total
/// resolve and from `move_space_to_display`, the one relocation
/// that bypasses the resolve on purpose; `healedSpaces` is
/// written by the heal file and cleared by the #634 reset, and
/// nowhere else. A third caller is a relocation the rule file
/// did not know about, and a third writer is a second answer to
/// which space is the ledger's.
///
/// Pinned by count per file, so a site added or removed reds on
/// arrival. Fails OPEN for a write through a helper the needles
/// do not spell (a `withHealedSpaces { }` closure), which is the
/// residue review carries.
@Suite("Empty-display heal seam")
struct EmptyDisplayHealSeamTests {
    /// Every file that may spell `healEmptyDisplays(` — the
    /// declaration counts as a site (one-line `func x(`).
    private let callers: [String: Int] = [
        "Profiles/KiwiCore+EmptyDisplayHeal.swift": 1,
        "Profiles/KiwiCore+SpaceDisplays.swift": 1,
        "Commands/KiwiCore+SpaceDisplayCommands.swift": 1,
    ]

    /// Every file that may WRITE `healedSpaces`: the mint, the
    /// gone-seed drop and the retire filter in the heal file; the
    /// first-launch reset.
    private let writers: [String: Int] = [
        "Profiles/KiwiCore+EmptyDisplayHeal.swift": 3,
        "App/KiwiCore+Reset.swift": 1,
    ]

    private static let writePattern = try! NSRegularExpression(
        pattern: #"healedSpaces(\[[^\]]*\])? = "#
    )

    private static func writes(in source: String) -> Int {
        Self.writePattern.numberOfMatches(
            in: source,
            range: NSRange(source.startIndex..., in: source)
        )
    }

    private func counts(
        _ measure: (String) -> Int
    ) throws -> [String: Int] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let key = String(file.path.dropFirst(prefix.count))
            let hits = measure(try SourceScan.strippedSource(at: file))
            if hits > 0 { counts[key] = hits }
        }
        return counts
    }

    private func pin(
        _ found: [String: Int],
        against allowed: [String: Int],
        subject: String
    ) {
        for (file, count) in found.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) \(subject) \(count)× — a new site owes "
                + "profiles.md ▸ #1175 and an entry here"
            #expect(allowed[file] == count, Comment(rawValue: unlisted))
        }
        for (file, expected) in allowed {
            let vanished =
                "\(file) no longer \(subject) \(expected)× — "
                + "re-pin or drop its entry"
            #expect(found[file] == expected, Comment(rawValue: vanished))
        }
    }

    @Test("The heal is reached from its two homes alone")
    func healHasTwoCallers() throws {
        let found = try counts { $0.occurrences(of: "healEmptyDisplays(") }
        #expect(!found.isEmpty)
        pin(found, against: callers, subject: "spells the heal")
    }

    @Test("The ledger is written by the heal and the reset alone")
    func ledgerHasTwoWriterFiles() throws {
        let found = try counts(Self.writes)
        #expect(!found.isEmpty)
        pin(found, against: writers, subject: "writes the ledger")
    }
}
