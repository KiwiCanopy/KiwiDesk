import Foundation

/// What a command is for (#2610): `list_commands --kind`, the MCP
/// listing's filter and the generated actions page read it.
/// Whether a command can be bound is its channel, not its kind.
public enum APIKind: String, Sendable, APIChoiceType {
    /// Does something: the commands a key usually runs.
    case action
    /// Changes a stored or live value.
    case setting
    /// Answers with state and changes nothing.
    case query
}

extension APIReference {
    /// The kind a name reads as: `set_*` sets, `get_*`, `list_*`
    /// and `current_*` ask, anything else acts. Read from the
    /// entry's own name, so `look.list` asks as `list_profiles`
    /// does.
    static func derivedKind(of name: String) -> APIKind {
        func starts(_ prefix: String) -> Bool {
            firstWord(of: name, is: prefix)
        }
        if starts("set") { return .setting }
        if ["get", "list", "current"].contains(where: starts) {
            return .query
        }
        return .action
    }

    /// True when `word` is the name's first word — the whole name,
    /// or the part before its first `_` — never a stem: `settle`
    /// does not start with `set`. The name-pattern censuses read
    /// it too.
    static func firstWord(of name: String, is word: String) -> Bool {
        name == word || name.hasPrefix(word + "_")
    }

    /// Qualified names whose kind their name misreads (#2610).
    /// `APIKindCensusTests` holds every row to a real entry whose
    /// derived kind differs from the one written here.
    public static let kindExceptions: [String: APIKind] = [
        // The layout hotkey, spelled as a setter.
        "set_mode": .action,
        "explain_window": .query,
        "explain_app": .query,
        "help": .query,
        "version": .query,
        "subscribe": .query,
        PrivatePathSelfTest.command: .query,
        "enable_wake_restore": .setting,
        "bind_profile_to_desktop": .setting,
        // The Screen pin, stored as the Desktop binding is.
        "pin_space_to_display": .setting,
        // Config-time declarations: they do nothing on a key.
        "bind": .setting,
        "on": .setting,
        "define_layer": .setting,
        KiwiCore.keepSettingsCommand: .setting,
        KiwiCore.revertSettingsCommand: .setting,
        // Writes `gap.global`.
        "border.fit_gaps": .setting,
        // Wears a look's values live, as its setters would.
        "look.apply": .setting,
        "shortcut.remove": .setting,
        "look.save": .setting,
        "look.delete": .setting,
        "kiwivision.define_lens": .setting,
        "kiwivision.delete_lens": .setting,
        "app_rule.remove_space": .setting,
        "app_rule.remove_float": .setting,
    ]

    /// The entry's kind: its exception row, else its name's.
    public static func kind(of entry: APIEntry) -> APIKind {
        kindExceptions[entry.qualifiedName]
            ?? derivedKind(of: entry.name)
    }

    /// `groups` narrowed to one kind, in their own order; a group
    /// left empty is dropped. Nil keeps every group whole.
    public static func groups(of kind: APIKind?) -> [APIGroup] {
        guard let kind else { return groups }
        return groups.compactMap { group in
            let kept = group.entries.filter { self.kind(of: $0) == kind }
            return kept.isEmpty
                ? nil : APIGroup(name: group.name, entries: kept)
        }
    }
}
