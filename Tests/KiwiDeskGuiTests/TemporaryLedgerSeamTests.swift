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
            (1, "arms a temporary Space that holds something"),
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
            let writes = [
                "temporaryArmed.insert(", "temporaryArmed.remove(",
                "temporaryArmed =",
            ].reduce(0) { $0 + source.occurrences(of: $1) }
            if writes > 0 {
                found[String(file.path.dropFirst(prefix.count))] = writes
            }
        }
        #expect(!found.isEmpty, "the scan found no writer at all")
        #expect(found == Self.writers.mapValues(\.0))
    }
}
