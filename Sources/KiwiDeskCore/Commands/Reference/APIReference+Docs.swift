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

    /// The `init.lua` call of a command, its arguments by name and
    /// an optional one in brackets; nil for a command Lua never
    /// registers.
    public static func luaCall(for entry: APIEntry) -> String? {
        guard entry.channel != .cli else { return nil }
        let function =
            entry.group == coreGroup
            ? "\(coreGroup).\(entry.name)" : entry.qualifiedName
        var arguments = ""
        for (index, argument) in entry.record.arguments.enumerated() {
            let lead = index == 0 ? "" : ", "
            arguments +=
                argument.isOptional
                ? "[\(lead)\(argument.name)]" : lead + argument.name
        }
        return "\(function)(\(arguments))"
    }
}
