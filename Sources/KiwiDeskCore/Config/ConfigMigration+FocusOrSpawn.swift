import Foundation

/// Renames the Open or Focus call inside a stored binding's `lua`
/// (#1511, `FocusOrSpawnMigrationTests`): `pull_or_spawn` went TO
/// a window and never pulled one, so the verb is `focus_or_spawn`.
/// The Settings app menu writes `KiwiDesk.pull_or_spawn("<id>")`
/// as every app shortcut's default, so without the step every one
/// would refuse on update. Only that exact shape crosses — the
/// app's own format, which `KeybindingCatalog.appCommand` writes;
/// any other Lua beside it is the user's script and stays loud.
/// It reaches every `lua` value at any depth: `gui.json`'s layers,
/// a profile's layer override, a bundle's inline copies.
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

    /// `lua` with its verb renamed when it is exactly a stored
    /// Open or Focus call — one quoted argument with no quote
    /// inside it — else nil.
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

    /// The text with every JSON string that spells a stored Open
    /// or Focus call renamed where it stands; the envelope discards
    /// an edit that reached a string the walk did not.
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
