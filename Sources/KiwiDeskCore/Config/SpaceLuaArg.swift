import Foundation

/// The single source of truth for how a `SpaceID` appears as the
/// argument of a generated `KiwiDesk.*` Lua call, shared by the
/// keybinding catalog (which authors the calls), the config
/// writer, and space rename (#13) — so the three never drift on
/// escaping and a rename can rewrite what the catalog produced.
public enum SpaceLuaArg {
    /// A quoted Lua string literal for a SpaceID. Delegates to
    /// `LuaLiteral.string` so keybinding args, the writer's
    /// `space_monitor_map`/`app_rules` keys, and rename all escape
    /// identically (including control characters, which a raw
    /// newline in a short string literal would otherwise make
    /// invalid Lua) — the single source of truth this type exists
    /// to guarantee.
    public static func quote(_ raw: String) -> String {
        LuaLiteral.string(raw)
    }

    /// The space-targeting Lua calls whose sole argument is a
    /// SpaceID literal. Each pattern includes the opening paren,
    /// so `move_to_virtual_space` never matches inside
    /// `move_to_virtual_space_and_follow`.
    static let spaceCalls = [
        "focus_virtual_space",
        "move_to_virtual_space",
        "move_to_virtual_space_and_follow",
    ]

    /// Rewrites every `<call>("from")` to `<call>("to")` within a
    /// single Lua binding body, matching the exact quoted form the
    /// catalog emitted. Only that quoted form is rewritten — a
    /// hand-written bare-number arg (`focus_virtual_space(2)`) is
    /// left untouched, consistent with such bindings being outside
    /// GUI management.
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
