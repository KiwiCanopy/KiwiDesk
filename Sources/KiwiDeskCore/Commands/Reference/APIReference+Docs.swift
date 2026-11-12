import Foundation

/// What links a command to its documentation (#3213): the names a
/// `lua-reference.md` heading carries, and the call a config
/// writes.
extension APIReference {
    /// The command names a docs heading names. A heading may name
    /// several, split on ` / ` or `, `, in backticks or not, and
    /// may spell a core command on its Lua table.
    public static func commandNames(inHeading title: String) -> [String] {
        let table = coreGroup + "."
        return title.replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: " / ", with: ", ")
            .components(separatedBy: ", ")
            .map { name in
                name.hasPrefix(table)
                    ? String(name.dropFirst(table.count)) : name
            }
    }

    /// The `init.lua` call of a command, its arguments by name —
    /// the one spelling `help` prints and its JSON carries; nil for
    /// a command Lua never registers.
    public static func luaCall(for entry: APIEntry) -> String? {
        guard entry.channel != .cli else { return nil }
        let arguments = entry.record.arguments.map(\.name)
            .joined(separator: ", ")
        return "\(luaFunction(of: entry))(\(arguments))"
    }
}
