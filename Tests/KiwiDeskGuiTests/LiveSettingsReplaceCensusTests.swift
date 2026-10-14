import Foundation
import Testing

/// Every wholesale write of the live settings takes the one
/// `replaceLiveSettings` door, which moves the epoch a change
/// report carries (#1685): a write beside it would replace a
/// session's unkept changes without the MCP server learning so.
@Suite("Live settings replace census")
struct LiveSettingsReplaceCensusTests {
    /// Files that may assign `tiler.settings` whole, and why.
    static let allowed: [String: String] = [
        "App/KiwiCore+LiveSettingsEpoch.swift": "the door itself",
        "App/KiwiCore+SharedLookWrite.swift":
            "reresolveLiveLook paints the look just stored, which a "
            + "change report reads as stored, not as replaced",
    ]

    @Test("tiler.settings is assigned whole only through the door")
    func oneDoor() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        var writers: Set<String> = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            scanned += 1
            let assigns =
                source.range(
                    of: #"tiler\.settings\s*=(?!=)"#,
                    options: .regularExpression
                ) != nil
            if assigns {
                writers.insert(String(file.path.dropFirst(prefix.count)))
            }
        }
        #expect(scanned > 0)
        #expect(
            writers == Set(Self.allowed.keys),
            "wholesale writers: \(writers.sorted())"
        )
    }
}
