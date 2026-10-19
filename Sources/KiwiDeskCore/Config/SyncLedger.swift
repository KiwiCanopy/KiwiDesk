import CryptoKit
import Foundation

/// Which version of each synced file this Mac and its sync folder
/// last agreed on (#2324 slice 3), by content hash — never by
/// modification date, which a sync app rewrites. A side that still
/// holds the agreed version did not change; the other side's
/// change is then the one to copy across. Our own copies leave both
/// sides equal, so they are never echoed back.
///
/// Kept in `MachineLocation`'s folder: it names this Mac's copy,
/// and another Mac's ledger is not this one.
struct SyncLedger: Codable, Equatable, Sendable {
    static let fileName = "sync-state.json"
    static let currentFormat = 1

    var format = SyncLedger.currentFormat
    /// The folder the hashes were agreed with, as the user named
    /// it; a ledger for another folder answers nothing.
    var folder: String
    /// Path below the setup's root → SHA-256, hex.
    var agreed: [String: String] = [:]

    /// The ledger stored at `url` for `folder`, nil where there is
    /// none, it names another folder or it does not read.
    static func load(from url: URL, for folder: URL) -> SyncLedger? {
        guard let data = try? Data(contentsOf: url),
            let ledger = try? JSONDecoder().decode(
                SyncLedger.self,
                from: data
            ),
            ledger.format <= currentFormat,
            ledger.folder == folder.standardizedFileURL.path
        else { return nil }
        return ledger
    }

    func save(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    /// `data`'s SHA-256, hex.
    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }
            .joined()
    }
}
