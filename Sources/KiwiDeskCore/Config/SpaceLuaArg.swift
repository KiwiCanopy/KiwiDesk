import Foundation

/// Serialization and parsing of SpaceID arguments in Lua call strings (#13).
public enum SpaceLuaArg {
    /// Quoted Lua string literal for a SpaceID (`LuaLiteral.string`).
    public static func quote(_ raw: String) -> String {
        LuaLiteral.string(raw)
    }

    /// Space-targeting Lua call prefixes. Each pattern includes
    /// the opening paren, so `move_to_space` never matches inside
    /// `move_to_space_and_follow`.
    static let spaceCalls = [
        "focus_space",
        "move_to_space",
        "move_to_space_and_follow",
    ]

    /// Extracts target SpaceID from catalog-authored Lua binding
    /// (`SpaceID`, #92).
    public static func targetSpace(
        of lua: String
    ) -> SpaceID? {
        guard lua.hasSuffix(")") else { return nil }
        for call in spaceCalls {
            let prefix = "KiwiDesk.\(call)("
            guard lua.hasPrefix(prefix) else { continue }
            let inner = String(
                lua.dropFirst(prefix.count).dropLast(1)
            )
            guard
                let raw = LuaLiteral.parseString(inner)
            else { return nil }
            return SpaceID(raw)
        }
        return nil
    }

    /// Renames the SpaceID argument in matching Lua call bodies
    /// (#13). Only the exact quoted form the catalog emits is
    /// rewritten — a hand-written bare-number arg stays untouched,
    /// consistent with such Lua being outside GUI management.
    public static func rename(
        in lua: String,
        from: String,
        to: String
    ) -> String {
        let old = quote(from)
        let new = quote(to)
        var result = lua
        for call in spaceCalls {
            result = result.replacingOccurrences(
                of: "\(call)(\(old))",
                with: "\(call)(\(new))"
            )
        }
        return result
    }
}
