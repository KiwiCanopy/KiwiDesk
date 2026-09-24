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

    public init(
        layers: [KeyLayer] = [],
        removed: [String: [String]] = [:]
    ) {
        self.layers = layers
        self.removed = removed.filter { !$0.value.isEmpty }
    }

    /// True when nothing diverges.
    public var isEmpty: Bool { layers.isEmpty && removed.isEmpty }

    /// Count of things this override overrides (#678 turn 13a).
    /// Not `flatMap(\.bindings).count`: `diff` emits a layer with
    /// NO bindings when only its icon diverges, so a diverging
    /// layer contributes at least itself. The invariant to keep is
    /// `isEmpty == (overrideCount == 0)`.
    public var overrideCount: Int {
        layers.reduce(0) { $0 + max($1.bindings.count, 1) }
            + removed.values.reduce(0) { $0 + $1.count }
    }

    /// Merges this override onto `base`: a left-out combo's base
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
        for baseLayer in base {
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
        where !consumed.contains(layer.name) {
            result.append(layer)
        }
        return result
    }
}

extension KeyLayerOverride {
    /// Inverse of `resolved(onto:)` — nil when nothing diverges.
    /// A base combo `edited` no longer binds in a layer it keeps
    /// is left out (#1393); a base layer `edited` drops entirely
    /// survives, as does a cleared base icon.
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
        let over = KeyLayerOverride(layers: layers, removed: removed)
        return over.isEmpty ? nil : over
    }
}

/// One stored layer entry: the layer, plus the base combos it
/// leaves out under `removed` (#1393). An entry carrying only
/// removals is no diverging layer of its own.
private struct KeyLayerOverrideEntry: Codable {
    var layer: KeyLayer
    var removed: [String]

    private enum CodingKeys: String, CodingKey { case removed }

    init(layer: KeyLayer, removed: [String]) {
        self.layer = layer
        self.removed = removed
    }

    init(from decoder: Decoder) throws {
        layer = try KeyLayer(from: decoder)
        removed =
            try decoder.container(keyedBy: CodingKeys.self)
            .decodeIfPresent([String].self, forKey: .removed) ?? []
    }

    func encode(to encoder: Encoder) throws {
        try layer.encode(to: encoder)
        guard !removed.isEmpty else { return }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(removed, forKey: .removed)
    }

    var removalOnly: Bool {
        !removed.isEmpty && layer.bindings.isEmpty && layer.icon == nil
    }
}

extension KeyLayerOverride: Codable {
    /// Decodes normalized sparse layer list (#31).
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let entries = try container.decode([KeyLayerOverrideEntry].self)
        var removed: [String: [String]] = [:]
        for entry in entries where !entry.removed.isEmpty {
            removed[entry.layer.name, default: []] += entry.removed
        }
        self.init(
            layers: KeyLayer.normalized(
                sparse: entries.filter { !$0.removalOnly }.map(\.layer)
            ),
            removed: removed
        )
    }

    public func encode(to encoder: Encoder) throws {
        var entries = layers.map {
            KeyLayerOverrideEntry(layer: $0, removed: removed[$0.name] ?? [])
        }
        let named = Set(layers.map(\.name))
        for name in removed.keys.sorted() where !named.contains(name) {
            entries.append(
                KeyLayerOverrideEntry(
                    layer: KeyLayer(name: name),
                    removed: removed[name] ?? []
                )
            )
        }
        var container = encoder.singleValueContainer()
        try container.encode(entries)
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
