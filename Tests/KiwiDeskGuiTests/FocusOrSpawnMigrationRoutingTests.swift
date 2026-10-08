import Foundation
import Testing

/// `ConfigMigration`'s focus-or-spawn step (#1511) renames by the
/// `lua` KEY at any depth, and `readBackup` runs it across a whole
/// `SetupBundle`, so a second `lua` CodingKey anywhere in the
/// config would hand the step a value it was never scoped to —
/// the argument `ConfigMigrationRoutingTests` makes for
/// `scroll_speed`. The retired verb is named by the step alone:
/// anywhere else it is an alias (AGENTS.md §5) or a GUI writing
/// the shape the step exists to retire.
@Suite("Focus or spawn migration scope (#1511)")
struct FocusOrSpawnMigrationRoutingTests {
    private var sources: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
    }

    private func scan(
        _ match: (String) -> Bool
    ) throws -> Set<String> {
        let prefix = sources.path + "/"
        var found: Set<String> = []
        for file in try SourceScan.swiftSources(under: sources) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            guard match(source) else { continue }
            found.insert(String(file.path.dropFirst(prefix.count)))
        }
        return found
    }

    @Test("the retired verb is named by the migration alone")
    func retiredVerbIsTheStepsAlone() throws {
        let named = try scan { $0.contains("\"pull_or_spawn\"") }
        #expect(
            named == [
                "KiwiDeskCore/Config/ConfigMigration+FocusOrSpawn.swift"
            ],
            Comment(
                rawValue: "`pull_or_spawn` still named in: "
                    + "\(named.sorted()) — only the migration may"
            )
        )
    }

    @Test("the step's `lua` key has one declarer")
    func luaKeyStaysUnique() throws {
        let declaring = try scan { source in
            source.contains("CodingKey")
                && source.range(
                    of: "case lua(?![A-Za-z0-9_(])",
                    options: .regularExpression
                ) != nil
        }
        #expect(
            declaring == ["KiwiDeskCore/Config/KeyLayer.swift"],
            Comment(
                rawValue: "`lua` CodingKeys: \(declaring.sorted()) — "
                    + "a second one is a value the #1511 rename "
                    + "reaches, or this set owes it an entry"
            )
        )
    }
}
