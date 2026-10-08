import Foundation

/// Sparse per-profile keybinding override (#55; tested in
/// `KeyLayerOverrideTests`).
public struct KeyLayerOverride: Sendable, Equatable {
    /// Sparse: only layers that diverge from the base.
    public var layers: [KeyLayer]
    /// Base combos this profile leaves out, per layer name — the
    /// tombstone that lets one profile drop or move a shared
    /// shortcut (#1393). Never empty per layer.
    public var removed: [String: [String]]
    /// Base layers this profile leaves out whole — the same mark
    /// one level up, so a profile created later still gets the
    /// shared layer (#2022). Never `default`, never repeated.
    public var leftOut: [String]

    public init(
        layers: [KeyLayer] = [],
        removed: [String: [String]] = [:],
        leftOut: [String] = []
    ) {
        self.layers = layers
        self.removed = removed.filter { !$0.value.isEmpty }
        var seen: Set<String> = [KeyLayer.defaultName]
        self.leftOut = leftOut.filter { seen.insert($0).inserted }
    }

    /// True when nothing diverges.
    public var isEmpty: Bool {
        layers.isEmpty && removed.isEmpty && leftOut.isEmpty
    }

    /// Count of things this override overrides (#678 turn 13a).
    /// Not `flatMap(\.bindings).count`: `diff` emits a layer with
    /// NO bindings when only its icon diverges, so a diverging
    /// layer contributes at least itself. The invariant to keep is
    /// `isEmpty == (overrideCount == 0)`.
    public var overrideCount: Int {
        layers.reduce(0) { $0 + max($1.bindings.count, 1) }
            + removed.values.reduce(0) { $0 + $1.count }
            + leftOut.count
    }

    /// Merges this override onto `base`: a left-out layer goes
    /// whole — its own rows here too — a left-out combo's base
    /// rows go, then the override wins per combo IN PLACE;
    /// unmentioned base combos and layers survive.
    /// `KeybindingMerge` folds by the same key with the OPPOSITE
    /// icon precedence — both are correct for their direction, do
    /// not unify them.
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
        let dropped = Set(leftOut)
        for baseLayer in base where !dropped.contains(baseLayer.name) {
            let over = overrideByName[baseLayer.name]
            let gone = removed[baseLayer.name] ?? []
            if over == nil && gone.isEmpty {
                result.append(baseLayer)
                continue
            }
            // EVERY matching base row is replaced — a hand-edited
            // duplicate base combo must not let a stale copy
            // outlive the override (registration is last-wins).
            var merged = baseLayer.bindings.filter {
                !gone.contains($0.combo)
            }
            for row in over?.bindings ?? [] {
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
                    icon: over?.icon ?? baseLayer.icon,
                    bindings: merged
                )
            )
            consumed.insert(baseLayer.name)
        }
        for layer in layers
        where !consumed.contains(layer.name)
            && !dropped.contains(layer.name)
        {
            result.append(layer)
        }
        return result
    }
}

extension KeyLayerOverride {
    /// Inverse of `resolved(onto:)` — nil when nothing diverges.
    /// A base combo `edited` no longer binds in a layer it keeps
    /// is left out (#1393), and a base layer `edited` drops
    /// entirely is left out whole (#2022); a cleared base icon
    /// survives.
    public static func diff(
        base: [KeyLayer],
        edited: [KeyLayer]
    ) -> KeyLayerOverride? {
        var baseByName: [String: KeyLayer] = [:]
        for layer in base {
            baseByName[layer.name] = layer
        }
        var layers: [KeyLayer] = []
        var removed: [String: [String]] = [:]
        for layer in edited {
            guard let baseLayer = baseByName[layer.name] else {
                layers.append(layer)
                continue
            }
            var gone: [String] = []
            for row in baseLayer.bindings
            where !row.combo.isEmpty && !gone.contains(row.combo)
                && !layer.bindings.contains(where: { $0.combo == row.combo })
            {
                gone.append(row.combo)
            }
            if !gone.isEmpty { removed[layer.name] = gone }
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
        let kept = Set(edited.map(\.name))
        let over = KeyLayerOverride(
            layers: layers,
            removed: removed,
            leftOut: base.map(\.name).filter { !kept.contains($0) }
        )
        return over.isEmpty ? nil : over
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
