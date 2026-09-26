import Foundation
import Testing

/// The `float_nudge` retirement (#1674) walks by KEY at any
/// depth, as #1020's rename does, so both spellings stay unique
/// in Core: a second `float_nudge` would be eaten by the walk,
/// and a second `float_placement` would put a value it was never
/// scoped to beside it. Split from `ConfigMigrationRoutingTests`
/// at the file ceiling.
@Suite("Config migration routing: float placement")
struct ConfigMigrationFloatPlacementRoutingTests {
    @Test("The float-nudge retirement stays scoped to one key")
    func floatPlacementKeyStaysUnique() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        // The CodingKey the walk lands on, and the migration's
        // own rename target, which no walk reaches.
        let allowedLive: Set<String> = [
            "Tiling/TilingSettings+Coding.swift",
            "Config/ConfigMigration+FloatPlacement.swift",
        ]
        let allowedRetired: Set<String> = [
            "Config/ConfigMigration+FloatPlacement.swift"
        ]
        var live: Set<String> = []
        var retired: Set<String> = []
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            if source.contains("\"float_placement\"") {
                live.insert(key)
            }
            if source.contains("\"float_nudge\"") {
                retired.insert(key)
            }
        }
        // The scan found its subject before judging it.
        #expect(!live.isEmpty)
        #expect(
            live == allowedLive,
            Comment(
                rawValue:
                    "`float_placement` declarations: "
                    + "\(live.sorted()) — a second one owes "
                    + "the migration's walk a path"
            )
        )
        #expect(
            retired == allowedRetired,
            Comment(
                rawValue:
                    "`float_nudge` still named in: "
                    + "\(retired.sorted()) — only the migration "
                    + "may name the retired key"
            )
        )
    }
}
