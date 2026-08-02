import Foundation

// MARK: - KeyLayerOverride

/// Sparse per-profile keybinding override (#55). nil (absent)
/// inherits the base `layers` (gui.json) entirely; present, it
/// shadows the base by layer name then by combo — the override's
/// binding for a combo wins, base combos it does not mention
/// survive (the switch-key-trap safeguard, O4 soft). A layer the
/// base lacks is appended. Every base layer the override does not
/// mention passes through unchanged, so the default layer and any
/// profile-switch binding are never dropped.
///
/// Keyed merge (layer name × combo), NOT a struct field-mirror —
/// so no reflection parity net applies (AGENTS.md §5); guarded
/// instead by a round-trip + resolve + default-layer-invariant
/// test in `KeyLayerOverrideTests`.
public struct KeyLayerOverride: Sendable, Equatable {
    /// Sparse: only layers that diverge from the base.
    public var layers: [KeyLayer]

    public init(layers: [KeyLayer] = []) {
        self.layers = layers
    }

    /// True when no layer diverges — a fully-inherited profile
    /// needs no stored override (drives sparse encoding).
    public var isEmpty: Bool { layers.isEmpty }

    /// Resolves this override onto `base`, producing the merged
    /// layer list. Returns `base` unchanged when empty.
    ///
    /// Merge rule (O4 soft base layer):
    /// - For each override layer matching a base layer by `name`:
    ///   per-combo merge (override wins IN PLACE, so the base
    ///   row order survives for GUI rendering; base combos not
    ///   in the override survive). Override `icon` wins when
    ///   non-nil; otherwise the base icon is kept.
    /// - An override layer absent from `base` is appended.
    /// - Base layers not in the override pass through unchanged
    ///   (default layer and switch-key bindings always survive).
    ///
    /// Sibling keyed merge: `KeybindingMerge` (GUI shortcut
    /// import) folds by the same name×combo key but with the
    /// OPPOSITE icon precedence (existing-wins). Both are
    /// correct for their direction — do not unify them.
    public func resolved(
        onto base: [KeyLayer]
    ) -> [KeyLayer] {
        guard !isEmpty else { return base }
        // Index override layers by name for O(n) lookup. The
        // assignment is last-wins, but duplicate names cannot
        // reach here: decode sanitizes them FIRST-wins
        // (`KeyLayer.normalized`), and `diff` keys by name.
        var overrideByName: [String: KeyLayer] = [:]
        for layer in layers {
            overrideByName[layer.name] = layer
        }
        var result: [KeyLayer] = []
        var consumed: Set<String> = []
        for baseLayer in base {
            guard let over = overrideByName[baseLayer.name] else {
                // Not in override — pass through unchanged.
                result.append(baseLayer)
                continue
            }
            // Merge bindings in base order: an overridden
            // combo replaces its base row in place (the GUI
            // renders resolved layers — rows must not jump);
            // combos new to the layer append at the end. EVERY
            // matching base row is replaced — a hand-edited
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
        // Append override layers absent from base.
        for layer in layers
        where !consumed.contains(layer.name) {
            result.append(layer)
        }
        return result
    }
}

// MARK: - Diff (inverse of resolved)

extension KeyLayerOverride {
    /// Inverse of `resolved(onto:)`: the sparse override that,
    /// resolved onto `base`, yields `edited`. Rows matching a
    /// base row SEMANTICALLY (`sameAction`: combo + lua —
    /// display-only kind/label differences from the GUI
    /// classifier never read as divergence) are inherited and
    /// omitted; a row whose combo is absent from base or whose
    /// action diverges is included. A layer absent from base is
    /// included whole. An edited icon differing from the base
    /// icon is carried (nil inherits — CLEARING a base icon
    /// per profile is therefore not expressible; it reverts,
    /// like row deletion). Returns nil when nothing diverges —
    /// a fully-inherited profile stores no override (O3
    /// sparse; an empty override is never persisted).
    ///
    /// DELETIONS are not expressible (O4 soft: base rows the
    /// override does not mention always survive) — a base row
    /// missing from `edited` is simply absent from the diff
    /// and reappears on resolve. The editor treats deleting an
    /// inherited row as revert, never removal; rebind to a
    /// no-op to disable a combo in one profile. No tombstones.
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
                // New layer: carried whole.
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

// MARK: - Codable

extension KeyLayerOverride: Codable {
    /// Transparent to [KeyLayer]: encode/decode as a bare JSON
    /// array, matching the `GuiConfig.layers` shape so both
    /// surfaces share one vocabulary (AGENTS.md §5).
    /// Decoded input is untrusted (hand-edited profile JSON,
    /// #31): duplicate names and a default-layer icon are
    /// normalized away. Sparse flavor — a default entry is
    /// never inserted (absence means inherit).
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

// MARK: - ConfigResolver

/// Thin resolver composing the base and profile keybinding
/// tiers (O1, AGENTS.md §5). Tiling tiers are unchanged:
/// `apply()` replaces base, `TilingSettings.resolvedX(for:)`
/// handles per-space — those are not re-implemented here.
public enum ConfigResolver {
    /// Returns the effective layer list: `base` (from gui.json)
    /// when `profile` is nil or empty; keyed name×combo merge
    /// otherwise. Mirrors `reapplyActiveProfileState` ordering
    /// — declarative Lua is the seed, profile wins.
    public static func resolvedLayers(
        base: [KeyLayer],
        profile: KeyLayerOverride?
    ) -> [KeyLayer] {
        profile?.resolved(onto: base) ?? base
    }
}
