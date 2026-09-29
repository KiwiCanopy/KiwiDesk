import Foundation

/// Serialization and parsing of SpaceID arguments in Lua call strings (#13).
public enum SpaceLuaArg {
    /// Quoted Lua string literal for a SpaceID (`LuaLiteral.string`).
    public static func quote(_ raw: String) -> String {
        LuaLiteral.string(raw)
    }

    /// Space-targeting Lua function call prefixes with SpaceID arguments.
    static let spaceCalls = [
        "focus_space",
        "move_to_space",
        "move_to_space_and_follow",
    ]

    /// A Space binding's action: the verb and the Space it
    /// targets — what "the same action" compares, never the raw
    /// Lua string (#1797).
    public struct Target: Hashable, Sendable {
        public let verb: String
        public let space: SpaceID
    }

    /// Extracts target SpaceID from catalog-authored Lua binding
    /// (`SpaceID`, #92).
    public static func targetSpace(
        of lua: String
    ) -> SpaceID? {
        target(of: lua)?.space
    }

    /// Extracts the verb and Space of a catalog-authored Lua
    /// binding, or nil for anything else.
    public static func target(of lua: String) -> Target? {
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
            return Target(verb: call, space: SpaceID(raw))
        }
        return nil
    }

    /// Renames SpaceID argument in matching Lua call bodies (#13).
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
