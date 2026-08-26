import Foundation

/// Assembles the per-group record tables into the surface
/// `list_commands` reports (#1033).
///
/// The name tables above stay authoritative: this file only
/// says which record table answers for which group, and the
/// entries below are DERIVED by walking `commands`,
/// `namespaces` and `luaOnly` and looking each name up. A name
/// with no record, or a record with no name, is what
/// `APIRecordCensusTests` reds on.
extension APIReference {
    /// The Lua table a dispatcher verb and a Lua-only entry
    /// point both live on. Namespaced commands name their own
    /// table instead.
    public static let coreGroup = "KiwiDesk"

    /// Dispatcher verbs, keyed by dispatcher command name.
    /// Split in two files for the size ceiling, joined here.
    ///
    /// A key in both halves would be a duplicated verb, which
    /// `APIRecordCensusTests` cannot see through a merge — so
    /// the join keeps the first and `duplicateCoreRecordKeys`
    /// reds on the overlap instead.
    public static let coreRecords: [String: APIRecord] =
        coreWindowRecords.merging(coreSettingRecords) { keep, _ in
            keep
        }

    /// Verbs recorded in both core files. Empty, and held so by
    /// `APIRecordCensusTests`.
    static var duplicateCoreRecordKeys: Set<String> {
        Set(coreWindowRecords.keys)
            .intersection(coreSettingRecords.keys)
    }

    /// Namespace tables → their records, keyed by the bare
    /// function name within the table.
    public static let namespaceRecords: [String: [String: APIRecord]] = [
        "animations": animationsRecords,
        "stack": stackRecords,
        "bsp": bspRecords,
        "scroll": scrollRecords,
        "space_bar": spaceBarRecords,
        "app_bar": appBarRecords,
        "grid": gridRecords,
        "monocle": monocleRecords,
        "track": trackRecords,
        "mouse": mouseRecords,
        "quit": quitRecords,
        "drag": dragRecords,
        "border": borderRecords,
        "sticky": stickyRecords,
        "floating": floatingRecords,
    ]
}

/// Which channels can reach a command.
public enum APIChannel: String, Sendable, Equatable {
    /// Lua, the CLI and the IPC socket — the ordinary case.
    case both
    /// Lua only: it bypasses the dispatcher (#37).
    case lua
    /// The socket only: no `KiwiDesk` table function exists.
    case cli
}

/// One command as `list_commands` reports it: where it lives,
/// what to call it, and its record.
public struct APIEntry: Sendable, Equatable {
    /// The Lua table — `KiwiDesk` or a namespace name.
    public let group: String
    /// The name within that group.
    public let name: String
    /// The dispatcher command, `nil` for a Lua-only entry.
    public let command: String?
    /// Other Lua spellings of the same command
    /// (`list_commands` for `help`).
    public let aliases: [String]
    public let channel: APIChannel
    public let record: APIRecord

    /// The name a caller types: `focus`, `scroll.set_anchor`.
    public var qualifiedName: String {
        group == APIReference.coreGroup
            ? name : "\(group).\(name)"
    }
}
