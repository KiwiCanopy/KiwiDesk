import Foundation

/// Command and API reference registry tables (`APIRecordCensusTests`, #1033).
extension APIReference {
    /// Default top-level Lua table name.
    public static let coreGroup = "KiwiDesk"

    /// Unified core command records (`APIRecordCensusTests`).
    public static let coreRecords: [String: APIRecord] =
        coreWindowRecords.merging(coreSettingRecords) { keep, _ in
            keep
        }

    /// Duplicate core record keys detected by `APIRecordCensusTests`.
    static var duplicateCoreRecordKeys: Set<String> {
        Set(coreWindowRecords.keys)
            .intersection(coreSettingRecords.keys)
    }

    /// Records grouped by namespace table.
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

/// Invocation channels reachable by a command (#37).
public enum APIChannel: String, Sendable, Equatable {
    case both
    case lua
    case cli
}

/// Command entry reported by `list_commands` (#1033).
public struct APIEntry: Sendable, Equatable {
    public let group: String
    public let name: String
    public let command: String?
    public let aliases: [String]
    public let channel: APIChannel
    public let record: APIRecord

    /// Qualified command call string.
    public var qualifiedName: String {
        group == APIReference.coreGroup
            ? name : "\(group).\(name)"
    }
}
