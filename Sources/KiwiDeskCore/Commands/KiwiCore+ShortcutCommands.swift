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
                            layer.bindings.filter { !$0.combo.isEmpty }.map {
                                .object([
                                    "chord": .string($0.combo),
                                    "lua": .string($0.lua),
                                ])
                            }
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
        guard var (snapshot, page) = shortcutPage() else {
            return Self.noShortcutPage
        }
        guard let layer = Self.defaultLayer(snapshot, page) else {
            return .fail("no default layer")
        }
        let key = RuleReachTable<String>.keyID(layer: layer, lua: lua)
        let table = snapshot.keyLayers
        let bound = table.resolved(for: page)
        if let held = bound[key] {
            return Self.sameChord(held, chord)
                ? .ok() : .fail("\(lua) is bound to \(held); remove it first")
        }
        if let rival = bound.first(where: { other in
            RuleReachTable<String>.keyParts(other.key).layer == layer
                && Self.sameChord(other.value, chord)
        }) {
            let action = RuleReachTable<String>.keyParts(rival.key).lua
            return .fail("\(chord) runs \(action); remove it first")
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
        guard var (snapshot, page) = shortcutPage() else {
            return Self.noShortcutPage
        }
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
            KeyCombo.parse(text) != nil
        else { return nil }
        return text.lowercased()
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
