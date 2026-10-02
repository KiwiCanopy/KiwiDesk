import Foundation
import Testing

/// "The last frame we sent this window" has one reading,
/// `TilingEngine.commandedFrame(of:)` (#1508): an animation's
/// target ahead of a recent instant set, since an animated apply
/// leaves the instant ledger standing. A reader spelling the two
/// rungs itself can put them in the other order, which is how
/// the stash's first copy read a stale corner over a move away.
@Suite("Commanded-frame seam (#1508)")
struct CommandedFrameSeamTests {
    private static let core = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/KiwiDeskCore")

    /// File → why it may read the instant ledger directly.
    static let allowed: [String: String] = [
        "TilingEngine+Layout.swift": "the accessor itself",
        "KiwiCore+Bootstrap.swift":
            "the overlay syncs read the instant set alone; the "
            + "animation reaches them on its own tick (#881)",
    ]

    @Test("only the ruled files read the instant ledger")
    func instantLedgerReaders() throws {
        let sites = try SourceScan.identifierSites(
            of: "recentInstantTarget(",
            under: Self.core
        )
        let files = Set(sites.map(\.file.lastPathComponent))
        #expect(!sites.isEmpty)
        #expect(
            files == Set(Self.allowed.keys),
            "found \(sites.map(\.site))"
        )
    }

    /// The applier is reachable from Core, so the ledger has a
    /// second spelling; only the accessor's file may take it.
    @Test("only the accessor reads the applier's ledger")
    func applierLedgerReaders() throws {
        let sites = try SourceScan.identifierSites(
            of: "applier.instantTarget(",
            under: Self.core
        )
        #expect(
            sites.map(\.file.lastPathComponent)
                == ["TilingEngine+Layout.swift"],
            "found \(sites.map(\.site))"
        )
    }
}
