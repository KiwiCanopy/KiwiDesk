import Foundation

/// `shortcut.list_groups` (#2544 ▸ Ruling): the names a binding's
/// `group` may take — the built-in groups by token, and every group
/// the installed shortcuts make of their own, in the order a binding
/// first names it.
extension KiwiCore {
    func shortcutGroupList() -> JSONValue {
        .object([
            "built_in": .array(
                ShortcutGroup.allCases.map { .string($0.rawValue) }
            ),
            "custom": .array(customShortcutGroups().map(JSONValue.string)),
        ])
    }

    /// One `shortcut.list` entry: its chord and Lua, and what it
    /// says of itself where it says anything (#2544).
    static func shortcutEntry(_ binding: KeyBinding) -> JSONValue {
        var entry: [String: JSONValue] = [
            "chord": .string(binding.combo),
            "lua": .string(binding.lua),
        ]
        if !binding.desc.isEmpty { entry["desc"] = .string(binding.desc) }
        if !binding.group.isEmpty { entry["group"] = .string(binding.group) }
        if !binding.symbol.isEmpty {
            entry["symbol"] = .string(binding.symbol)
        }
        return .object(entry)
    }

    /// The groups the installed shortcuts make, every layer and the
    /// chords whose body was not read back included — read live, as
    /// installed, where `shortcut.list` reads the files.
    func customShortcutGroups() -> [String] {
        guard let snapshot = liveKeybindingSnapshot() else { return [] }
        return ShortcutGroup.custom(
            in: snapshot.metaByChord().map(\.meta.group)
        )
    }
}
