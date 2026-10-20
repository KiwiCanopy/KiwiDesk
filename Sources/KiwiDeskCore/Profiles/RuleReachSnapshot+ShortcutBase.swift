import Foundation

/// The "Shortcuts use" switch over the stored shortcut files
/// (#2460): the shared keymap's rows move onto the new base, and
/// every profile follows them, so a row a profile left out stays
/// out there. Laid over the files AHEAD of the row encode, like the
/// layer pass.
extension RuleReachSnapshot {
    /// Moves the base's rows onto `base` — save those `staying`
    /// names by layer — and each profile's override after them
    /// (`KeyLayerOverride.following`). Moving onto the base the rows
    /// are already on moves nothing, so a second run is inert.
    public mutating func moveShortcutBase(
        onto base: ShortcutBase,
        liveSpaces: Set<SpaceID>,
        staying: (String, KeyBinding) -> Bool
    ) throws {
        try refuseAfterRowEncode()
        var moves: [String: [String: KeyBinding]] = [:]
        storedKeyBase = storedKeyBase.map { layer in
            let next = ShortcutBaseSwitch.move(
                layer,
                onto: base,
                liveSpaces: liveSpaces
            ) { staying(layer.name, $0) }
            if !next.moves.isEmpty { moves[layer.name] = next.moves }
            return next.layer
        }
        guard !moves.isEmpty else { return }
        storedKeyOverrides = storedKeyOverrides.mapValues {
            $0.following(moves)
        }
        rebuildKeyTable()
    }
}

extension KeyLayerOverride {
    /// This override after its base moved `moves` — per layer, each
    /// moved row by its old chord — so the profile resolves as it
    /// did: a tombstone on an old chord takes the new one; a base
    /// row this override replaced by its old chord is left out at
    /// the new one; and a base row its own row now replaces at the
    /// new chord stays on the old one as the profile's own row. A
    /// layer the override leaves out whole needs nothing.
    public func following(
        _ moves: [String: [String: KeyBinding]]
    ) -> KeyLayerOverride {
        var removed = self.removed
        var layers = self.layers
        for (layer, map) in moves where !leftOut.contains(layer) {
            var gone = removed[layer] ?? []
            let at = layers.firstIndex { $0.name == layer }
            let own = Set(at.map { layers[$0].bindings.map(\.combo) } ?? [])
            var kept: [KeyBinding] = []
            for (old, row) in map.sorted(by: { $0.key < $1.key }) {
                let new = row.combo
                if let index = gone.firstIndex(of: old) {
                    if gone.contains(new) {
                        gone.remove(at: index)
                    } else {
                        gone[index] = new
                    }
                } else if own.contains(old) {
                    if !gone.contains(new) { gone.append(new) }
                } else if own.contains(new) {
                    var stays = row
                    stays.combo = old
                    kept.append(stays)
                }
            }
            removed[layer] = gone
            guard !kept.isEmpty else { continue }
            if let at {
                layers[at].bindings += kept
            } else {
                layers.append(KeyLayer(name: layer, bindings: kept))
            }
        }
        return KeyLayerOverride(
            layers: layers,
            removed: removed,
            leftOut: leftOut
        )
    }
}
