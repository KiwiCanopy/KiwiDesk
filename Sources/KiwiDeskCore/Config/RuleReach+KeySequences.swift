import Foundation

// A key sequence in the key table (#3124): keyed by its layer and
// leader chord, its value the whole tree, since a profile holds or
// overrides a sequence whole (#1871). Every reader asking what chord
// a key holds, or whether a key is a sequence, goes through here.

extension RuleReachTable where Value == String {
    /// What a sequence key carries in the action slot ahead of its
    /// leader chord; no Lua a row runs starts with it.
    static let sequenceMark = "\u{1E}"

    /// The key of the sequence `leader` opens in `layer`.
    public static func sequenceID(layer: String, leader: String) -> String {
        keyID(layer: layer, lua: sequenceMark + leader)
    }

    /// The leader chord a sequence key names; nil for an action's key.
    public static func leader(of key: String) -> String? {
        let lua = keyParts(key).lua
        guard lua.hasPrefix(sequenceMark) else { return nil }
        return String(lua.dropFirst(sequenceMark.count))
    }

    /// Whether `key` names a key sequence.
    public static func isSequenceKey(_ key: String) -> Bool {
        leader(of: key) != nil
    }

    /// The chord `key` holds at `value`: an action's combo, or a
    /// sequence's leader, which its key carries.
    public static func chord(of key: String, value: String) -> String {
        leader(of: key) ?? value
    }

    /// The key a layer row is filed under, nil for a row the table
    /// does not name — an unbound sequence, an action with no Lua.
    public static func key(of row: KeyBinding, layer: String) -> String? {
        if row.isSequence {
            guard !row.combo.isEmpty else { return nil }
            return sequenceID(layer: layer, leader: row.combo)
        }
        guard !row.lua.isEmpty else { return nil }
        return keyID(layer: layer, lua: row.lua)
    }

    /// The value a layer row is filed at: its combo, or a sequence's
    /// whole tree in one canonical spelling, which carries no row id.
    public static func value(of row: KeyBinding) -> String {
        guard row.isSequence else { return row.combo }
        return sequenceValue(row)
    }

    /// `tree` as the key table stores it.
    public static func sequenceValue(_ tree: KeyBinding) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(tree) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// The tree a sequence key's value spells; nil for any other.
    public static func sequenceTree(_ value: String) -> KeyBinding? {
        try? JSONDecoder().decode(KeyBinding.self, from: Data(value.utf8))
    }

    /// `layer`'s rows the table names, each with its key, in row
    /// order.
    static func keyedRows(_ layer: KeyLayer)
        -> [(key: String, row: KeyBinding)]
    {
        layer.bindings.compactMap { row in
            key(of: row, layer: layer.name).map { ($0, row) }
        }
    }

    /// The sequences on `leader` in `layers[at]` become exactly
    /// `trees`, each taking the leader over from any row bound to it;
    /// the first keeps the old one's place.
    static func setSequences(
        _ layers: inout [KeyLayer],
        _ at: Int?,
        _ leader: String,
        _ trees: [KeyBinding]
    ) {
        guard let at else {
            // Which layers exist is the layer pass's (#2022).
            if !trees.isEmpty {
                assertionFailure("sequence \(leader) written with no layer")
            }
            return
        }
        var rows = layers[at].bindings
        let place = rows.firstIndex { $0.isSequence && $0.combo == leader }
        rows.removeAll {
            $0.combo == leader && ($0.isSequence || !trees.isEmpty)
        }
        let index = min(place ?? rows.count, rows.count)
        rows.insert(contentsOf: trees, at: index)
        layers[at].bindings = rows
    }

    /// Writes a sequence key's `value` into `layers`: the tree on its
    /// leader, or none for nil — what a page takes from a write made
    /// outside it.
    public static func writeSequence(
        _ layers: inout [KeyLayer],
        key: String,
        value: String?
    ) {
        guard let leader = leader(of: key) else { return }
        let at = layers.firstIndex { $0.name == keyParts(key).layer }
        setSequences(
            &layers,
            at,
            leader,
            value.flatMap(sequenceTree).map {
                [$0]
            } ?? []
        )
    }

    /// Whether two of `key`'s values hold the same chord in rival
    /// keys — what a takeover compares.
    static func holdsChord(
        _ rival: String,
        _ value: String?,
        _ chord: String
    ) -> Bool {
        value.map { Self.chord(of: rival, value: $0) } == chord
    }
}
