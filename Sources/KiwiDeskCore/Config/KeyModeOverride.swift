import Foundation

// MARK: - KeyModeOverride

/// Sparse per-profile keybinding override (#55). nil (absent)
/// inherits the base `modes` (gui.json) entirely; present, it
/// shadows the base by mode name then by combo — the override's
/// binding for a combo wins, base combos it does not mention
/// survive (the switch-key-trap safeguard, O4 soft). A mode the
/// base lacks is appended. Every base mode the override does not
/// mention passes through unchanged, so the default mode and any
/// profile-switch binding are never dropped.
///
/// Keyed merge (mode name × combo), NOT a struct field-mirror —
/// so no reflection parity net applies (AGENTS.md §5); guarded
/// instead by a round-trip + resolve + default-mode-invariant
/// test in `KeyModeOverrideTests`.
public struct KeyModeOverride: Sendable, Equatable {
    /// Sparse: only modes that diverge from the base.
    public var modes: [KeyMode]

    public init(modes: [KeyMode] = []) {
        self.modes = modes
    }

    /// True when no mode diverges — a fully-inherited profile
    /// needs no stored override (drives sparse encoding).
    public var isEmpty: Bool { modes.isEmpty }

    /// Resolves this override onto `base`, producing the merged
    /// mode list. Returns `base` unchanged when empty.
    ///
    /// Merge rule (O4 soft base layer):
    /// - For each override mode matching a base mode by `name`:
    ///   per-combo merge (override wins IN PLACE, so the base
    ///   row order survives for GUI rendering; base combos not
    ///   in the override survive). Override `icon` wins when
    ///   non-nil; otherwise the base icon is kept.
    /// - An override mode absent from `base` is appended.
    /// - Base modes not in the override pass through unchanged
    ///   (default mode and switch-key bindings always survive).
    ///
    /// Sibling keyed merge: `KeybindingMerge` (GUI shortcut
    /// import) folds by the same name×combo key but with the
    /// OPPOSITE icon precedence (existing-wins). Both are
    /// correct for their direction — do not unify them.
    public func resolved(
        onto base: [KeyMode]
    ) -> [KeyMode] {
        guard !isEmpty else { return base }
        // Index override modes by name for O(n) lookup.
        var overrideByName: [String: KeyMode] = [:]
        for mode in modes {
            overrideByName[mode.name] = mode
        }
        var result: [KeyMode] = []
        var consumed: Set<String> = []
        for baseMode in base {
            guard let over = overrideByName[baseMode.name] else {
                // Not in override — pass through unchanged.
                result.append(baseMode)
                continue
            }
            // Merge bindings in base order: an overridden
            // combo replaces its base row in place (the GUI
            // renders resolved modes — rows must not jump);
            // combos new to the mode append at the end. EVERY
            // matching base row is replaced — a hand-edited
            // duplicate base combo must not let a stale copy
            // outlive the override (registration is last-wins).
            var merged = baseMode.bindings
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
                KeyMode(
                    name: baseMode.name,
                    icon: over.icon ?? baseMode.icon,
                    bindings: merged
                )
            )
            consumed.insert(baseMode.name)
        }
        // Append override modes absent from base.
        for mode in modes
        where !consumed.contains(mode.name) {
            result.append(mode)
        }
        return result
    }
}

// MARK: - Diff (inverse of resolved)

extension KeyModeOverride {
    /// Inverse of `resolved(onto:)`: the sparse override that,
    /// resolved onto `base`, yields `edited`. Rows equal to
    /// their base row (`KeyBinding ==`, id excluded) are
    /// inherited and omitted; a row whose combo is absent from
    /// base or whose action diverges is included. A mode
    /// absent from base is included whole. An edited icon
    /// differing from the base icon is carried (nil inherits).
    /// Returns nil when nothing diverges — a fully-inherited
    /// profile stores no override (O3 sparse; an empty
    /// override is never persisted).
    ///
    /// DELETIONS are not expressible (O4 soft: base rows the
    /// override does not mention always survive) — a base row
    /// missing from `edited` is simply absent from the diff
    /// and reappears on resolve. The editor treats deleting an
    /// inherited row as revert, never removal; rebind to a
    /// no-op to disable a combo in one profile. No tombstones.
    public static func diff(
        base: [KeyMode],
        edited: [KeyMode]
    ) -> KeyModeOverride? {
        var baseByName: [String: KeyMode] = [:]
        for mode in base {
            baseByName[mode.name] = mode
        }
        var modes: [KeyMode] = []
        for mode in edited {
            guard let baseMode = baseByName[mode.name] else {
                // New mode: carried whole.
                modes.append(mode)
                continue
            }
            var rows: [KeyBinding] = []
            for row in mode.bindings {
                let inherited = baseMode.bindings.contains {
                    $0 == row
                }
                if !inherited {
                    rows.append(row)
                }
            }
            let icon =
                mode.icon != baseMode.icon ? mode.icon : nil
            if !rows.isEmpty || icon != nil {
                modes.append(
                    KeyMode(
                        name: mode.name,
                        icon: icon,
                        bindings: rows
                    )
                )
            }
        }
        let over = KeyModeOverride(modes: modes)
        return over.isEmpty ? nil : over
    }
}

// MARK: - Codable

extension KeyModeOverride: Codable {
    /// Transparent to [KeyMode]: encode/decode as a bare JSON
    /// array, matching the `GuiConfig.modes` shape so both
    /// surfaces share one vocabulary (AGENTS.md §5).
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        modes = try container.decode([KeyMode].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(modes)
    }
}

// MARK: - ConfigResolver

/// Thin resolver composing the base and profile keybinding
/// tiers (O1, AGENTS.md §5). Tiling tiers are unchanged:
/// `apply()` replaces base, `TilingSettings.resolvedX(for:)`
/// handles per-space — those are not re-implemented here.
public enum ConfigResolver {
    /// Returns the effective mode list: `base` (from gui.json)
    /// when `profile` is nil or empty; keyed name×combo merge
    /// otherwise. Mirrors `reapplyActiveProfileState` ordering
    /// — declarative Lua is the seed, profile wins.
    public static func resolvedModes(
        base: [KeyMode],
        profile: KeyModeOverride?
    ) -> [KeyMode] {
        profile?.resolved(onto: base) ?? base
    }
}
