import Foundation

/// Taking a gone Space's shortcuts out of the files (#1827): every
/// row whose Lua names one of the Spaces — `focus_space`,
/// `move_to_space`, `move_to_space_and_follow` — in the base
/// layers and in each profile's override. Pure; the write is
/// `KiwiCore+SpaceShortcutDrop`'s.
extension Array where Element == KeyLayer {
    /// These layers without a row naming one of `spaces`, and the
    /// combos taken from each layer, by layer name.
    public func removingRows(
        naming spaces: Set<SpaceID>
    ) -> (layers: [KeyLayer], removed: [String: [String]]) {
        var removed: [String: [String]] = [:]
        let layers = map { layer -> KeyLayer in
            let gone = layer.pressBindings.filter { $0.names(spaces) }
            if !gone.isEmpty { removed[layer.name] = gone.map(\.combo) }
            // A sequence keeps its leader and loses the end keys
            // naming a gone Space (#1871): it is no row taken.
            return layer.mappingActions { $0.names(spaces) ? nil : $0 }
        }
        return (layers, removed)
    }
}

extension KeyLayerOverride {
    /// This override without a row naming one of `spaces`, and
    /// without a tombstone for a base row `baseRemoved` took — a
    /// mark with no row under it would remove the next row bound
    /// to that combo. An override of a `baseLayers` layer the drop
    /// emptied goes; a profile's own layer, or one diverging by its
    /// icon, stays. Nil where nothing is left to override.
    public func removingRows(
        naming spaces: Set<SpaceID>,
        baseRemoved: [String: [String]],
        baseLayers: Set<String>
    ) -> KeyLayerOverride? {
        var marks: [String: [String]] = [:]
        for (name, combos) in removed {
            let gone = baseRemoved[name] ?? []
            let kept = combos.filter { mark in
                !gone.contains { Self.sameChord($0, mark) }
            }
            if !kept.isEmpty { marks[name] = kept }
        }
        let kept = zip(layers, layers.removingRows(naming: spaces).layers)
            .filter { before, after in
                before.bindings.isEmpty || !after.bindings.isEmpty
                    || after.icon != nil
                    || !baseLayers.contains(after.name)
            }
            .map(\.1)
        let trimmed = KeyLayerOverride(
            layers: kept,
            removed: marks,
            leftOut: leftOut
        )
        return trimmed.isEmpty ? nil : trimmed
    }

    /// One chord: parsed where both parse, else the same spelling.
    private static func sameChord(_ a: String, _ b: String) -> Bool {
        guard let left = KeyCombo.parse(a), let right = KeyCombo.parse(b)
        else { return a == b }
        return left == right
    }
}

extension KeyBinding {
    /// Whether this row's Lua names one of `spaces`; a sequence
    /// asks each of its end keys (#1871).
    func names(_ spaces: Set<SpaceID>) -> Bool {
        if isSequence {
            return endKeys.contains { $0.binding.names(spaces) }
        }
        return SpaceLuaArg.target(of: lua).map {
            spaces.contains($0.space)
        } ?? false
    }
}
