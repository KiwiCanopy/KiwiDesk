import Foundation
import Testing

/// `ConfigMigration`'s focus-or-spawn step (#1511) renames by the
/// `lua` KEY at any depth, and `readBackup` runs it across a whole
/// `SetupBundle`, so a second `lua` key anywhere in the config
/// would hand the step a value it was never scoped to — the
/// argument `ConfigMigrationRoutingTests` makes for `scroll_speed`.
/// The retired verb is named by the step and by the retired-verb
/// list alone: anywhere else it is a live spelling of a verb that
/// no longer exists, or a GUI writing the shape the step retires.
///
/// Known limit: a `lua` key is seen as an explicit `case lua`
/// CodingKey or a stored `lua: String` in a Codable file; one
/// spelled through a renamed key or a non-String type is not.
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

    private func matches(_ pattern: String, in source: String) -> Bool {
        source.range(of: pattern, options: .regularExpression) != nil
    }

    @Test("the retired verb is named by the step and the retired list")
    func retiredVerbIsTheStepsAlone() throws {
        let named = try scan { $0.contains("\"pull_or_spawn\"") }
        #expect(
            named == [
                "KiwiDeskCore/Config/ConfigMigration+FocusOrSpawn.swift",
                "KiwiDeskCore/Commands/Reference/APIReference+Retired.swift",
            ],
            Comment(
                rawValue: "`pull_or_spawn` still named in: "
                    + "\(named.sorted()) — only the migration and "
                    + "the retired list may"
            )
        )
    }

    @Test("the step's `lua` key has one declarer")
    func luaKeyStaysUnique() throws {
        let declaring = try scan { source in
            let codingKey =
                source.contains("CodingKey")
                && matches("case lua(?![A-Za-z0-9_(])", in: source)
            let synthesized =
                matches("Codable|Decodable|Encodable", in: source)
                && matches("(var|let) lua\\s*:\\s*String", in: source)
            return codingKey || synthesized
        }
        #expect(
            declaring == ["KiwiDeskCore/Config/KeyLayer.swift"],
            Comment(
                rawValue: "`lua` keys: \(declaring.sorted()) — "
                    + "a second one is a value the #1511 rename "
                    + "reaches, or this set owes it an entry"
            )
        )
    }
}
