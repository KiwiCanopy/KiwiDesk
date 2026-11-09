import Foundation

/// The derived command sets, split from `APIReference.swift` at the
/// §2.1 ceiling.
extension APIReference {
    /// Command names reachable through dispatcher and CLI/IPC (#37).
    public static var dispatchable: [String] {
        var names = Set(commands.map(\.command))
        for (table, functions) in namespaces {
            for function in functions {
                names.insert("\(table).\(function)")
            }
        }
        names.formUnion(cliOnly)
        return names.sorted()
    }

    /// Full set of command names for census cross-checking
    /// (`APIRecordCensusTests`, `CLIHelpSeamTests`, #1033).
    public static var allCommands: [String] {
        Set(dispatchable).union(luaOnly).sorted()
    }
}
