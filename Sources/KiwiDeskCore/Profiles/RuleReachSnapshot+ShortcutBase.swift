import Foundation

/// The "Shortcuts use" switch over the stored shortcut files
/// (#2460): the shared keymap's rows move onto the new base, and
/// every profile's tombstone naming a moved row's old chord moves
/// with it, so a row a profile left out stays out there. Laid over
/// the files AHEAD of the row encode, like the layer pass.
extension RuleReachSnapshot {
    /// Moves the base's rows onto `base` — save those `staying`
    /// names by layer — and each profile's tombstones after them.
    /// A layer a profile leaves out whole needs nothing.
    public mutating func moveShortcutBase(
        onto base: ShortcutBase,
        staying: (String, KeyBinding) -> Bool
    ) throws {
        try refuseAfterRowEncode()
        var moves: [String: [String: String]] = [:]
        storedKeyBase = storedKeyBase.map { layer in
            let next = ShortcutBaseSwitch.moved(layer, onto: base) {
                staying(layer.name, $0)
            }
            for (old, new) in zip(layer.bindings, next.bindings)
            where old.combo != new.combo {
                moves[layer.name, default: [:]][old.combo] = new.combo
            }
            return next
        }
        guard !moves.isEmpty else { return }
        storedKeyOverrides = storedKeyOverrides.mapValues {
            $0.following(moves)
        }
        rebuildKeyTable()
    }
}

extension KeyLayerOverride {
    /// This override after its base moved `moves` (old chord → new,
    /// per layer): a tombstone on an old chord takes the new one,
    /// and a base row this override replaced by its chord is left
    /// out at its new one, so the profile still goes without it.
    public func following(
        _ moves: [String: [String: String]]
    ) -> KeyLayerOverride {
        var removed = self.removed
        for (layer, map) in moves where !leftOut.contains(layer) {
            var gone = removed[layer] ?? []
            let own = Set(
                layers.first { $0.name == layer }?.bindings.map(\.combo)
                    ?? []
            )
            for (old, new) in map.sorted(by: { $0.key < $1.key }) {
                if let at = gone.firstIndex(of: old) {
                    if gone.contains(new) {
                        gone.remove(at: at)
                    } else {
                        gone[at] = new
                    }
                } else if own.contains(old), !gone.contains(new) {
                    gone.append(new)
                }
            }
            removed[layer] = gone
        }
        return KeyLayerOverride(
            layers: layers,
            removed: removed,
            leftOut: leftOut
        )
    }
}
