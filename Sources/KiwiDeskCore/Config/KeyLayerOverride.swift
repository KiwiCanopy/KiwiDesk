import Foundation

/// Sparse per-profile keybinding override (#55; tested in
/// `KeyLayerOverrideTests`).
public struct KeyLayerOverride: Sendable, Equatable {
    /// Sparse: only layers that diverge from the base.
    public var layers: [KeyLayer]

    public init(layers: [KeyLayer] = []) {
        self.layers = layers
    }

    /// True when no layer diverges.
    public var isEmpty: Bool { layers.isEmpty }

    /// Count of things this override overrides (#678 turn 13a).
    /// Not `flatMap(\.bindings).count`: `diff` emits a layer with
    /// NO bindings when only its icon diverges, so a diverging
    /// layer contributes at least itself. The invariant to keep is
    /// `isEmpty == (overrideCount == 0)`.
    public var overrideCount: Int {
        layers.reduce(0) { $0 + max($1.bindings.count, 1) }
    }

    /// Merges this override onto `base` (O4 soft: override wins
    /// per combo IN PLACE, unmentioned base combos and layers
    /// survive). `KeybindingMerge` folds by the same key with the
    /// OPPOSITE icon precedence — both are correct for their
    /// direction, do not unify them.
    public func resolved(
        onto base: [KeyLayer]
    ) -> [KeyLayer] {
        guard !isEmpty else { return base }
        var overrideByName: [String: KeyLayer] = [:]
        for layer in layers {
            overrideByName[layer.name] = layer
        }
        var result: [KeyLayer] = []
        var consumed: Set<String> = []
        for baseLayer in base {
            guard let over = overrideByName[baseLayer.name] else {
                result.append(baseLayer)
                continue
            }
            // EVERY matching base row is replaced — a hand-edited
            // duplicate base combo must not let a stale copy
            // outlive the override (registration is last-wins).
            var merged = baseLayer.bindings
            for row in over.bindings {
                var replaced = false
                for at in merged.indices
                where merged[at].combo == row.combo {
                    merged[at] = row
                    replaced = true
                }
                if !replaced {
                    merged.append(row)
                }
            }
            result.append(
                KeyLayer(
                    name: baseLayer.name,
                    icon: over.icon ?? baseLayer.icon,
                    bindings: merged
                )
            )
            consumed.insert(baseLayer.name)
        }
        for layer in layers
        where !consumed.contains(layer.name) {
            result.append(layer)
        }
        return result
    }
}

extension KeyLayerOverride {
    /// Inverse of `resolved(onto:)` — nil when nothing diverges.
    /// DELETIONS are not expressible (O4 soft: unmentioned base
    /// rows always survive): the editor treats deleting an
    /// inherited row as revert, never removal — rebind to a no-op
    /// to disable a combo in one profile. No tombstones.
    public static func diff(
        base: [KeyLayer],
        edited: [KeyLayer]
    ) -> KeyLayerOverride? {
        var baseByName: [String: KeyLayer] = [:]
        for layer in base {
            baseByName[layer.name] = layer
        }
        var layers: [KeyLayer] = []
        for layer in edited {
            guard let baseLayer = baseByName[layer.name] else {
                layers.append(layer)
                continue
            }
            var rows: [KeyBinding] = []
            for row in layer.bindings {
                let inherited = baseLayer.bindings.contains {
                    $0.sameAction(as: row)
                }
                if !inherited {
                    rows.append(row)
                }
            }
            let icon =
                layer.icon != baseLayer.icon ? layer.icon : nil
            if !rows.isEmpty || icon != nil {
                layers.append(
                    KeyLayer(
                        name: layer.name,
                        icon: icon,
                        bindings: rows
                    )
                )
            }
        }
        let over = KeyLayerOverride(layers: layers)
        return over.isEmpty ? nil : over
    }
}

extension KeyLayerOverride: Codable {
    /// Decodes normalized sparse layer list (#31).
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        layers = KeyLayer.normalized(
            sparse: try container.decode([KeyLayer].self)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(layers)
    }
}

/// Resolver composing base and profile keybinding tiers.
public enum ConfigResolver {
    /// Returns effective layers merging `profile` onto `base`.
    public static func resolvedLayers(
        base: [KeyLayer],
        profile: KeyLayerOverride?
    ) -> [KeyLayer] {
        profile?.resolved(onto: base) ?? base
    }
}
