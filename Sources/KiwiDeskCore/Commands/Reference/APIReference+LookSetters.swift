import Foundation

extension APIReference {
    /// The command that sets one look path (#1685): `a.b[.c]` is
    /// `a.set_b[_c]`, save the global gaps, which are a top-level
    /// verb. Nil for a path no catalogued command sets
    /// (`LookSetterCensusTests` holds every look path to one).
    public static func lookSetter(for path: String) -> String? {
        if path == "gap.global" { return "set_gap_global" }
        let parts = path.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return nil }
        let name =
            "\(parts[0]).set_"
            + parts.dropFirst().joined(separator: "_")
        return dispatchable.contains(name) ? name : nil
    }

    /// The Lua function an entry is called as: a dispatcher verb and
    /// a Lua-only entry point through the global `KiwiDesk` table, a
    /// namespace function through its own table — the one spelling
    /// help and a bound shortcut share (#1685).
    public static func luaFunction(of entry: APIEntry) -> String {
        entry.group == coreGroup
            ? "KiwiDesk.\(entry.name)" : entry.qualifiedName
    }
}
