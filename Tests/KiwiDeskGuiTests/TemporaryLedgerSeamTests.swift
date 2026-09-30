import Foundation
import Testing

/// Whether a Space is temporary is derived (#1790); the one thing
/// stored is `temporaryArmed`, and every file that writes it is
/// counted here with its reason — a writer beside them reds.
@Suite("Temporary Space ledger seam (#1790)")
struct TemporaryLedgerSeamTests {
    /// File → (writes of `temporaryArmed`, why it may).
    private static let writers: [String: (Int, String)] = [
        "Profiles/KiwiCore+TemporarySpaces.swift":
            (
                2,
                "arms a temporary Space that holds something, and "
                    + "drops the arm of one declared since"
            ),
        "Profiles/KiwiCore+TemporarySpaceBoot.swift":
            (1, "boot restores the armed flag"),
        "Profiles/KiwiCore+HeldSpaces.swift":
            (1, "a held one comes back armed"),
        "Profiles/KiwiCore+ProfileSpaces.swift":
            (1, "the one Space drop ends its entry"),
    ]

    @Test("every writer of the armed ledger is listed")
    func writersAreCounted() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: file)
            // Every mutating spelling of a `Set`, and an assignment
            // but not a comparison.
            let writes = [
                "temporaryArmed.insert(", "temporaryArmed.remove(",
                "temporaryArmed.removeAll(", "temporaryArmed.update(",
                "temporaryArmed.formUnion(", "temporaryArmed.subtract(",
                "temporaryArmed.formIntersection(",
                "temporaryArmed.formSymmetricDifference(",
                "temporaryArmed = ",
            ].reduce(0) { $0 + source.occurrences(of: $1) }
            if writes > 0 {
                found[String(file.path.dropFirst(prefix.count))] = writes
            }
        }
        #expect(!found.isEmpty, "the scan found no writer at all")
        #expect(found == Self.writers.mapValues(\.0))
    }

    /// Every door that moves what is live and what is declared holds
    /// the retire off while it runs, so a Space it is about to
    /// declare is never judged temporary (#1790).
    @Test("the moving doors hold the retire off")
    func movingDoorsHoldTheRetire() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: file)
            let holds = source.occurrences(
                of: "profiles.arrangementInFlight += 1"
            )
            if holds > 0 { found[file.lastPathComponent] = holds }
        }
        #expect(
            found == [
                "KiwiCore+Config.swift": 1,
                "KiwiCore+ProfileResolution.swift": 2,
            ]
        )
    }
}
