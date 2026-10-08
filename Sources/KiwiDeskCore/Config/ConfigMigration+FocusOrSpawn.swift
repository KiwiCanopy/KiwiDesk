import Foundation

/// Renames a stored `lua` value, under that key at any depth, that is
/// exactly `KiwiDesk.pull_or_spawn("<id>")` — one quoted argument with
/// no quote inside — to `focus_or_spawn` (#1511,
/// `FocusOrSpawnMigrationTests`). Any other spelling is left alone.
/// No format floor, deliberately: the rename is idempotent, and one
/// shared `file:` floor cannot state gui.json's 6 and a profile's 17.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps naming
    /// what it was written to name.
    static let retiredFocusOrSpawnVerb = "pull_or_spawn"
    static let focusOrSpawnVerb = "focus_or_spawn"
    static let focusOrSpawnLuaKey = "lua"

    @Sendable
    static func migratingRetiredPullOrSpawn(_ data: Data) -> Data? {
        let needle = Data("KiwiDesk.\(retiredFocusOrSpawnVerb)(".utf8)
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: {
                rewritingValues(of: $0, at: focusOrSpawnLuaKey) {
                    ($0 as? String).flatMap(renamedOpenOrFocusCall)
                }
            },
            editing: surgicallyRenamedOpenOrFocusCalls
        )
    }

    /// `lua` with its verb renamed when it is exactly the stored
    /// call, else nil.
    static func renamedOpenOrFocusCall(_ lua: String) -> String? {
        let prefix = "KiwiDesk.\(retiredFocusOrSpawnVerb)(\""
        let suffix = "\")"
        guard lua.hasPrefix(prefix), lua.hasSuffix(suffix),
            lua.count > prefix.count + suffix.count
        else { return nil }
        let inner = lua.dropFirst(prefix.count).dropLast(suffix.count)
        guard !inner.contains("\"") else { return nil }
        return "KiwiDesk.\(focusOrSpawnVerb)(\"\(inner)\")"
    }

    /// The text with every JSON string spelling the stored call
    /// renamed where it stands; the envelope discards an edit that
    /// reached a string the walk did not.
    private static func surgicallyRenamedOpenOrFocusCalls(
        _ text: String
    ) -> Data? {
        let pattern =
            "\"KiwiDesk\\.\(retiredFocusOrSpawnVerb)\\(\\\\\""
            + "((?:[^\"\\\\]|\\\\[^\"])+)\\\\\"\\)\""
        let out = text.replacingOccurrences(
            of: pattern,
            with: "\"KiwiDesk.\(focusOrSpawnVerb)(\\\\\"$1\\\\\")\"",
            options: .regularExpression
        )
        return out == text ? nil : out.data(using: .utf8)
    }
}
