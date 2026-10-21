import Foundation
import Testing

/// `on_expand` and `expand_duration` are `AnimationSettings` keys
/// and nothing else, and `on_shelf` / `shelf_duration` are keys
/// nowhere at all (owner ruling, 2026-10-21).
///
/// `ConfigMigration`'s expand step renames by KEY at any depth,
/// across a whole `SetupBundle`, so a second key of either retired
/// name anywhere in the config would be renamed by a step never
/// scoped to it — the argument `ConfigMigrationRoutingTests` makes
/// for `scroll_speed`.
@Suite("Expand duration migration scope")
struct ExpandDurationMigrationRoutingTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    @Test("the expand renames stay scoped to their keys")
    func expandKeysStayUnique() throws {
        let prefix = coreRoot.path + "/"
        // The CodingKeys the walk lands on and the step's own
        // rename targets.
        let allowedLive: Set<String> = [
            "Tiling/AnimationSettings.swift",
            "Config/ConfigMigration+ExpandDuration.swift",
        ]
        // Only the migration may still name the retired keys.
        let allowedRetired: Set<String> = [
            "Config/ConfigMigration+ExpandDuration.swift"
        ]
        var live: Set<String> = []
        var retired: Set<String> = []
        for file in try SourceScan.swiftSources(under: coreRoot) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            if source.contains("\"on_expand\"")
                || source.contains("\"expand_duration\"")
            {
                live.insert(key)
            }
            if source.contains("\"on_shelf\"")
                || source.contains("\"shelf_duration\"")
            {
                retired.insert(key)
            }
        }
        #expect(
            live == allowedLive,
            Comment(
                rawValue: "expand key declarations: \(live.sorted())"
                    + " — a second one owes the step a path, or this"
                    + " map a narrower home"
            )
        )
        #expect(
            retired == allowedRetired,
            Comment(
                rawValue: "a retired shelf-glide key is still named "
                    + "in: \(retired.sorted()) — only the migration may"
            )
        )
    }
}
