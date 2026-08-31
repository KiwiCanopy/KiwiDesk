import Foundation

/// Maps API names to structured documentation records (#1033).
extension APIReference {
    /// Command group section in command listing.
    public struct APIGroup: Sendable, Equatable {
        public let name: String
        public let entries: [APIEntry]
    }

    /// All command groups in display order.
    public static let groups: [APIGroup] =
        [APIGroup(name: coreGroup, entries: coreEntries)]
        + namespaces.keys.sorted().map { table in
            APIGroup(
                name: table,
                entries: namespaceEntries(of: table)
            )
        }

    /// Flattened list of all command entries.
    public static let entries: [APIEntry] = groups.flatMap(
        \.entries
    )

    /// Looks up command entry by canonical name or alias.
    public static func entry(named name: String) -> APIEntry? {
        entriesByName[name]
    }

    /// Name and alias lookup index for fast entry resolution.
    private static let entriesByName: [String: APIEntry] =
        entries.reduce(into: [:]) { table, entry in
            table[entry.qualifiedName] = entry
            for alias in entry.aliases { table[alias] = entry }
        }

    /// Core command entries (`APIRecordCensusTests`, `APIRecordFilledTests`).
    static var coreEntries: [APIEntry] {
        var aliases: [String: [String]] = [:]
        var order: [String] = []
        for entry in commands {
            if aliases[entry.command] == nil {
                order.append(entry.command)
            }
            aliases[entry.command, default: []].append(entry.lua)
        }
        let records = coreRecords
        var result = order.map { command -> APIEntry in
            let spellings = aliases[command] ?? [command]
            let canonical =
                spellings.contains(command)
                ? command : (spellings.first ?? command)
            return APIEntry(
                group: coreGroup,
                name: canonical,
                command: command,
                aliases: spellings.filter { $0 != canonical },
                channel: .both,
                record: records[command] ?? Self.pendingRecord
            )
        }
        result.append(
            APIEntry(
                group: coreGroup,
                name: socketOnlyCommand,
                command: socketOnlyCommand,
                aliases: [],
                channel: .cli,
                record: records[socketOnlyCommand]
                    ?? Self.pendingRecord
            )
        )
        result += luaOnly.map { name in
            APIEntry(
                group: coreGroup,
                name: name,
                command: nil,
                aliases: [],
                channel: .lua,
                record: luaOnlyRecords[name] ?? Self.pendingRecord
            )
        }
        return result
    }

    /// Namespace table command entries in declaration order.
    static func namespaceEntries(of table: String) -> [APIEntry] {
        let records = namespaceRecords[table] ?? [:]
        return (namespaces[table] ?? []).map { function in
            APIEntry(
                group: table,
                name: function,
                command: "\(table).\(function)",
                aliases: [],
                channel: .both,
                record: records[function] ?? Self.pendingRecord
            )
        }
    }

    /// Fallback record when documentation is pending
    /// (`APIRecord.pendingSummary`).
    private static let pendingRecord = APIRecord(
        APIRecord.pendingSummary
    )

    /// Socket-only command without a KiwiDesk table mapping.
    public static let socketOnlyCommand = "subscribe"
}
