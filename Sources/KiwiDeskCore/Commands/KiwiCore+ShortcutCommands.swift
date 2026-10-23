import Foundation

/// The `shortcut.*` verbs (#1685 ▸ Ruling 6c). A shortcut loads only
/// from the files, so a write saves at once — the shortcut rows
/// alone, through the App Rules page's door at the encoder's default
/// reach, never a profile save. `set` binds a COMMAND `run` could
/// send, its Lua call built here, never raw Lua; it refuses a chord
/// or a command already bound in the layer, so it replaces nothing.
extension KiwiCore {
    func shortcutCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "shortcut.list":
            return shortcutPage().map { .ok(shortcutList($0)) }
                ?? Self.noShortcutPage
        case "shortcut.set":
            return setShortcut(args)
        case "shortcut.remove":
            return removeShortcut(args)
        case "shortcut.list_groups":
            return .ok(shortcutGroupList())
        default:
            return .fail("unknown command: \(command)")
        }
    }

    /// The rule snapshot and the live page a write edits; nil where
    /// `init.lua` owns the shortcuts or no saved profile is live.
    private func shortcutPage() -> (RuleReachSnapshot, String)? {
        guard let snapshot = ruleReachSnapshot(),
            let page = profiles.currentName
        else { return nil }
        return (snapshot, page)
    }

    private func shortcutList(_ page: (RuleReachSnapshot, String)) -> JSONValue
    {
        let layers = page.0.storedKeyLayers(for: page.1)
        return .object([
            "profile": .string(page.1),
            "layers": .array(
                layers.map { layer in
                    .object([
                        "name": .string(layer.name),
                        "default": .bool(layer.isDefault),
                        "shortcuts": .array(
                            layer.bindings.filter { !$0.combo.isEmpty }.map(
                                Self.shortcutEntry
                            )
                        ),
                    ])
                }
            ),
        ])
    }

    private func setShortcut(_ args: [JSONValue]) -> CommandResponse {
        guard let chord = Self.chord(args.first) else { return Self.noChord }
        guard let name = args.dropFirst().first?.stringValue else {
            return .fail("expected a command")
        }
        let given: [JSONValue]
        if args.count == 3, case .array(let list) = args[2] {
            given = list
        } else {
            given = Array(args.dropFirst(2))
        }
        let lua: String
        switch ShortcutCall.lua(name, given) {
        case .failure(let refusal): return .fail(refusal.reason)
        case .success(let call): lua = call
        }
        guard let found = shortcutPage() else {
            return Self.noShortcutPage
        }
        var snapshot = found.0
        let page = found.1
        guard let layer = Self.defaultLayer(snapshot, page) else {
            return .fail("no default layer")
        }
        let key = RuleReachTable<String>.keyID(layer: layer, lua: lua)
        let table = snapshot.keyLayers
        if table.resolved(key, for: page).map({ Self.sameChord($0, chord) })
            == true
        {
            return .ok()
        }
        // Judged across the base and every profile, since a shared
        // row reaches them all: never a second chord for an action
        // (profiles.md ▸ one chord per layer), never a chord taken.
        let wanted = KeyBinding(combo: chord, lua: lua)
        for row in Self.rows(of: table, layer: layer) {
            if NavigationChords.sameAction(row, wanted) {
                return .fail(
                    "\(lua) is bound to \(row.combo); remove it first"
                )
            }
            if Self.sameChord(row.combo, chord) {
                return .fail("\(chord) runs \(row.lua); remove it first")
            }
        }
        snapshot.keyTemplates[key] = KeyBinding(combo: chord, lua: lua)
        snapshot.keyLayers.applyKey(
            key,
            value: chord,
            reach: table.defaultReach(of: key, editing: page, isLoaded: true),
            editing: page
        )
        return writeShortcuts(snapshot)
    }

    private func removeShortcut(_ args: [JSONValue]) -> CommandResponse {
        guard let chord = Self.chord(args.first) else { return Self.noChord }
        guard let found = shortcutPage() else {
            return Self.noShortcutPage
        }
        var snapshot = found.0
        let page = found.1
        guard let layer = Self.defaultLayer(snapshot, page),
            let key = snapshot.keyLayers.resolved(for: page).first(where: {
                RuleReachTable<String>.keyParts($0.key).layer == layer
                    && Self.sameChord($0.value, chord)
            })?.key
        else { return .fail("no shortcut on \(chord)") }
        let table = snapshot.keyLayers
        snapshot.keyLayers.applyKey(
            key,
            value: nil,
            reach: table.defaultReach(of: key, editing: page, isLoaded: true),
            editing: page
        )
        return writeShortcuts(snapshot)
    }

    private func writeShortcuts(_ snapshot: RuleReachSnapshot)
        -> CommandResponse
    {
        do {
            try saveRuleReach(snapshot, origin: .outside)
            return .ok()
        } catch {
            return .fail("shortcuts not saved: \(error)")
        }
    }

    /// Every row `layer` holds in the base or any profile.
    private static func rows(
        of table: RuleReachTable<String>,
        layer: String
    ) -> [KeyBinding] {
        let maps =
            [table.base] + table.profiles.map { table.resolved(for: $0) }
        return maps.flatMap { map in
            map.compactMap { key, combo in
                let parts = RuleReachTable<String>.keyParts(key)
                return parts.layer == layer
                    ? KeyBinding(combo: combo, lua: parts.lua) : nil
            }
        }
    }

    private static func defaultLayer(
        _ snapshot: RuleReachSnapshot,
        _ page: String
    ) -> String? {
        snapshot.storedKeyLayers(for: page).first(where: \.isDefault)?.name
    }

    /// A chord `KeyCombo` can register, as given.
    private static func chord(_ value: JSONValue?) -> String? {
        guard
            let text = value?.stringValue?
                .trimmingCharacters(in: .whitespaces),
            let combo = KeyCombo.parse(text)
        else { return nil }
        // Stored as the recorder and the seed spell it, so a plain
        // string compare (`takeOver`) finds it.
        return combo.comboString()
    }

    private static func sameChord(_ a: String, _ b: String) -> Bool {
        KeyCombo.parse(a).map { $0 == KeyCombo.parse(b) } ?? false
    }

    private static var noChord: CommandResponse {
        .fail("expected a chord such as ctrl+alt+h")
    }

    private static var noShortcutPage: CommandResponse {
        .fail(
            "shortcuts are writable only with a saved profile live and "
                + "no init.lua"
        )
    }
}
