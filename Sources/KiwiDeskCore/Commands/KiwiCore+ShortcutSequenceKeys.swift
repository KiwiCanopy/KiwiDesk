import Foundation

/// The key-at-a-time sequence verbs (#3174 ▸ Ruling), mirroring
/// Settings' Add Key: `set_sequence_key` writes one end key, making
/// the leader and any missing branch on the way; `name_sequence_key`
/// names a leader or branch and sets its icon; `remove_sequence_key`
/// removes one key with everything under it. An end key runs a
/// command built by `ShortcutCall`, never raw Lua, and each write
/// saves at once through `shortcut.set`'s door at its reach.
extension KiwiCore {
    func setSequenceKey(_ args: [JSONValue]) -> CommandResponse {
        guard let leader = Self.chord(args.first) else {
            return Self.noChord
        }
        guard let path = SequenceKeyEdit.path(args.dropFirst().first),
            !path.isEmpty
        else { return Self.noPath }
        if let refused = SequenceKeyEdit.admission(path, under: leader) {
            return .fail(refused.reason)
        }
        guard let name = args.dropFirst(2).first?.stringValue else {
            return .fail("expected a command")
        }
        let given: [JSONValue]
        if args.count == 4, case .array(let list) = args[3] {
            given = list
        } else {
            given = Array(args.dropFirst(3))
        }
        let lua: String
        switch ShortcutCall.lua(name, given) {
        case .failure(let refusal): return .fail(refusal.reason)
        case .success(let call): lua = call
        }
        // Stored as `shortcut.set` stores a row; Settings files its
        // kind and label on load (`KeybindingImportClassifier`).
        return editSequence(leader, creating: true) { root in
            SequenceKeyEdit.adding(
                KeyBinding(lua: lua),
                at: path,
                in: root
            )
        }
    }

    func nameSequenceKey(_ args: [JSONValue]) -> CommandResponse {
        guard let leader = Self.chord(args.first) else {
            return Self.noChord
        }
        guard let path = SequenceKeyEdit.path(args.dropFirst().first)
        else { return Self.noPath }
        guard let name = args.dropFirst(2).first?.stringValue else {
            return .fail("expected a name")
        }
        let symbol = args.dropFirst(3).first?.stringValue
        if let symbol, !symbol.isEmpty, !Self.iconIsSymbol(symbol) {
            return .fail("\(symbol) is not an SF Symbol name")
        }
        return editSequence(leader, creating: false) { root in
            SequenceKeyEdit.updating(at: path, in: root) { node in
                guard node.isSequence else {
                    return SequenceKeyEdit.Refusal(
                        reason: "only a leader or a key that opens keys "
                            + "takes a name; "
                            + "\(SequenceKeyEdit.spelled(path)) runs a "
                            + "command"
                    )
                }
                node.label = name
                if let symbol { node.symbol = symbol }
                return nil
            }
        }
    }

    func removeSequenceKey(_ args: [JSONValue]) -> CommandResponse {
        guard let leader = Self.chord(args.first) else {
            return Self.noChord
        }
        guard let path = SequenceKeyEdit.path(args.dropFirst().first)
        else { return Self.noPath }
        guard !path.isEmpty else {
            return .fail(
                "expected a path of keys; shortcut.remove_sequence "
                    + "removes a whole sequence"
            )
        }
        return editSequence(leader, creating: false) { root in
            SequenceKeyEdit.removing(at: path, from: root)
        }
    }

    /// Edits the sequence `leader` opens in the default layer and
    /// saves it at its reach. With `creating`, a leader no sequence
    /// holds starts an empty one, once `setShortcut`'s checks find
    /// its chord free.
    private func editSequence(
        _ leader: String,
        creating: Bool,
        _ edit: (KeyBinding) -> Result<KeyBinding, SequenceKeyEdit.Refusal>
    ) -> CommandResponse {
        guard let found = shortcutPage() else {
            return Self.noShortcutPage
        }
        var snapshot = found.0
        let page = found.1
        guard let layer = Self.defaultLayer(snapshot, page) else {
            return .fail("no default layer")
        }
        let table = snapshot.keyLayers
        let map = table.resolved(for: page)
        let key: String
        let root: KeyBinding
        if let held = RuleReachTable<String>.sequenceKey(
            on: leader,
            layer: layer,
            in: map
        ),
            let tree = map[held].flatMap(RuleReachTable<String>.sequenceTree)
        {
            key = held
            root = tree
        } else {
            guard creating else {
                return .fail("no key sequence on \(leader)")
            }
            if let taken = Self.chordTaken(leader, in: table, layer: layer) {
                return .fail(taken)
            }
            key = RuleReachTable<String>.sequenceID(
                layer: layer,
                leader: leader
            )
            root = .sequence(combo: leader)
        }
        let tree: KeyBinding
        switch edit(root) {
        case .failure(let refusal): return .fail(refusal.reason)
        case .success(let edited): tree = edited
        }
        snapshot.keyTemplates[key] = tree
        snapshot.keyLayers.applyKey(
            key,
            value: RuleReachTable<String>.sequenceValue(tree),
            reach: table.defaultReach(of: key, editing: page, isLoaded: true),
            editing: page
        )
        return writeShortcuts(snapshot)
    }

    private static var noPath: CommandResponse {
        .fail("expected a path of keys such as w,h")
    }
}
