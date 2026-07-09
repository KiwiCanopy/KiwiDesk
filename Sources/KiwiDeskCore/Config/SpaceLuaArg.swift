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

    /// Every space-targeting command as `(canonical bare-space
    /// name, legacy *_virtual_space alias)` — the ONE source for
    /// the rename (#42). The classifier's `canonicalSpaceLua` and
    /// `spaceCalls` below both derive from this, and
    /// `APIReference` is pinned to it by a parity test, so a new
    /// space verb is declared in exactly one place.
    public static let spaceCommandAliases:
        [(canonical: String, alias: String)] = [
            ("focus_space", "focus_virtual_space"),
            ("move_to_space", "move_to_virtual_space"),
            (
                "move_to_space_and_follow",
                "move_to_virtual_space_and_follow"
            ),
        ]

    /// The space-targeting Lua calls whose sole argument is a
    /// SpaceID literal — both canonical and legacy alias forms
    /// (#42), so a rename rewrites a binding authored in either.
    /// Each pattern includes the opening paren, so `move_to_space`
    /// never matches inside `move_to_space_and_follow`.
    static let spaceCalls: [String] =
        spaceCommandAliases.flatMap { [$0.canonical, $0.alias] }

    /// Rewrites every `<call>("from")` to `<call>("to")` within a
    /// single Lua binding body, matching the exact quoted form the
    /// catalog emitted. Only that quoted form is rewritten — a
    /// hand-written bare-number arg (`focus_space(2)`) is
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
