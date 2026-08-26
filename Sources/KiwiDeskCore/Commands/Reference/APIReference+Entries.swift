import Foundation

/// Walks the name tables and pairs each name with its record
/// (#1033).
///
/// Order is the tables' own declaration order, not alphabetical:
/// `commands` reads navigation → Spaces → windows → settings →
/// profiles, which is how someone scanning the listing wants to
/// meet them. Flattening that into one alphabetical run is half
/// of what #1033 was filed about.
extension APIReference {
    /// One group of the listing, in print order.
    public struct APIGroup: Sendable, Equatable {
        public let name: String
        public let entries: [APIEntry]
    }

    /// Every command, grouped: the `KiwiDesk` table first, then
    /// the namespace tables alphabetically.
    ///
    /// Stored, not computed: the tables it walks are compile-time
    /// constants, and `help` asks for the listing and then looks
    /// one name up in it.
    public static let groups: [APIGroup] =
        [APIGroup(name: coreGroup, entries: coreEntries)]
        + namespaces.keys.sorted().map { table in
            APIGroup(
                name: table,
                entries: namespaceEntries(of: table)
            )
        }

    /// Every command in every group, flattened.
    public static let entries: [APIEntry] = groups.flatMap(
        \.entries
    )

    /// The entry a caller named — `focus`, `scroll.set_anchor`,
    /// or an alias such as `list_commands`. Nil when nothing
    /// answers to it.
    public static func entry(named name: String) -> APIEntry? {
        entriesByName[name]
    }

    /// Every name an entry answers to, including aliases.
    private static let entriesByName: [String: APIEntry] =
        entries.reduce(into: [:]) { table, entry in
            table[entry.qualifiedName] = entry
            for alias in entry.aliases { table[alias] = entry }
        }

    /// The `KiwiDesk` table: the dispatcher verbs in declaration
    /// order, then `subscribe` (socket-only), then the Lua-only
    /// entry points.
    ///
    /// A record missing for a name falls back to a pending record
    /// rather than dropping the command from the listing — the
    /// listing must never be shorter than the API. Both guards
    /// see it: `APIRecordCensusTests` names the missing key, and
    /// `APIRecordFilledTests` asserts that no record is pending.
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
                record: records[command]
                    ?? APIRecord(APIRecord.pendingSummary)
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
                    ?? APIRecord(APIRecord.pendingSummary)
            )
        )
        result += luaOnly.map { name in
            APIEntry(
                group: coreGroup,
                name: name,
                command: nil,
                aliases: [],
                channel: .lua,
                record: luaOnlyRecords[name]
                    ?? APIRecord(APIRecord.pendingSummary)
            )
        }
        return result
    }

    /// One namespace table's entries, in its declared order.
    static func namespaceEntries(of table: String) -> [APIEntry] {
        let records = namespaceRecords[table] ?? [:]
        return (namespaces[table] ?? []).map { function in
            APIEntry(
                group: table,
                name: function,
                command: "\(table).\(function)",
                aliases: [],
                channel: .both,
                record: records[function]
                    ?? APIRecord(APIRecord.pendingSummary)
            )
        }
    }

    /// The one command reachable over the socket that has no
    /// `KiwiDesk` table function — `dispatchable` inserts it by
    /// hand, and so does the census.
    public static let socketOnlyCommand = "subscribe"
}
