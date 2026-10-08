import Foundation

// Shortcuts as a `RuleReachTable` (#1393): a key is one action in
// one layer, its value the combo. "Left out" is the override's
// removed combo (`KeyLayerOverride.removed`), and a row written
// into a profile takes its combo over from whatever that profile
// bound there (`applyKey`).

extension RuleReachTable where Value == String {
    /// The key of `lua` in `layer`.
    public static func keyID(layer: String, lua: String) -> String {
        layer + "\u{1F}" + lua
    }

    /// The layer and action a key names.
    public static func keyParts(_ key: String) -> (layer: String, lua: String)
    {
        let parts = key.split(
            separator: "\u{1F}",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        return (String(parts[0]), parts.count > 1 ? String(parts[1]) : "")
    }

    /// Each action's combo per layer — the first row where an
    /// action is bound twice.
    public static func combos(_ layers: [KeyLayer]) -> [String: String] {
        var result: [String: String] = [:]
        for layer in layers {
            for row in layer.bindings where !row.lua.isEmpty {
                let key = keyID(layer: layer.name, lua: row.lua)
                if result[key] == nil { result[key] = row.combo }
            }
        }
        return result
    }

    /// Every combo each action holds per layer, in row order.
    static func allCombos(_ layers: [KeyLayer]) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for layer in layers {
            for row in layer.bindings where !row.lua.isEmpty {
                result[keyID(layer: layer.name, lua: row.lua), default: []]
                    .append(row.combo)
            }
        }
        return result
    }

    /// The shortcut family, each profile read through the override
    /// resolution the engine registers.
    public static func keyLayers(
        base: [KeyLayer],
        overrides: [(profile: String, override: KeyLayerOverride?)]
    ) -> Self {
        let shared = combos(base)
        var entries: [String: [String: String?]] = [:]
        for (profile, override) in overrides {
            let own = combos(override?.resolved(onto: base) ?? base)
            var entry: [String: String?] = [:]
            for (key, combo) in own where shared[key] != combo {
                entry[key] = combo
            }
            for key in shared.keys where own[key] == nil {
                entry.updateValue(nil, forKey: key)
            }
            entries[profile] = entry
        }
        return Self(
            base: shared,
            entries: entries,
            profiles: overrides.map(\.profile)
        )
    }

    /// `apply`, then the takeover: where `key` now holds `value` —
    /// the base, or a profile — another action bound to that combo
    /// in the same layer loses it, recorded in the table so the
    /// pill and its own row see it.
    public mutating func applyKey(
        _ key: String,
        value: String?,
        reach: RuleReach,
        removal: RuleRemoval = .everywhere,
        editing: String
    ) {
        let old = base[key]
        apply(
            key,
            value: value,
            reach: reach,
            removal: removal,
            editing: editing
        )
        guard let value, !value.isEmpty else { return }
        let ticked: Set<String>
        switch reach {
        case .shared(let joining): ticked = joining
        case .listed(let members): ticked = members
        }
        takeOver(
            key,
            value: value,
            from: old,
            rivals: rivals(of: key),
            ticked: ticked,
            editing: editing
        )
    }

    /// The other actions in `key`'s layer — the keys a combo written
    /// for `key` may take its combo from.
    public func rivals(of key: String) -> [String] {
        let layer = Self.keyParts(key).layer
        return Set(base.keys).union(entries.values.flatMap(\.keys))
            .filter { $0 != key && Self.keyParts($0).layer == layer }
            .sorted()
    }

    /// The action `profile` binds to `key`'s combo instead, if any —
    /// the one ticking would take the key from.
    public func rival(of key: String, for profile: String, combo: String)
        -> String?
    {
        rivals(of: key).first { resolved($0, for: profile) == combo }
    }

    /// `profile`'s override: its stored one resolved onto the NEW
    /// base, the touched keys rewritten, diffed back through the
    /// override primitive.
    public func keyLayerOverride(
        for profile: String,
        original: KeyLayerOverride?,
        newBase: [KeyLayer],
        templates: [String: KeyBinding]
    ) -> KeyLayerOverride? {
        let keys = touched[profile] ?? []
        guard !keys.isEmpty else { return original }
        var desired = original?.resolved(onto: newBase) ?? newBase
        for key in keys.sorted() {
            Self.set(
                &desired,
                key,
                resolved(key, for: profile),
                templates[key]
            )
        }
        return KeyLayerOverride.diff(base: newBase, edited: desired)
    }

    /// Rewrites `key`'s row in `layers`: removed, then — for a
    /// combo — added from `template`, taking the combo over from
    /// any row bound to it.
    static func set(
        _ layers: inout [KeyLayer],
        _ key: String,
        _ combo: String?,
        _ template: KeyBinding?
    ) {
        setRows(&layers, key, combo.map { [$0] } ?? [], template)
    }

    /// `key`'s rows in `layers` become exactly `combos`, each taking
    /// its combo over from any row bound to it.
    static func setRows(
        _ layers: inout [KeyLayer],
        _ key: String,
        _ combos: [String],
        _ template: KeyBinding?
    ) {
        let (name, lua) = keyParts(key)
        let at = layers.firstIndex { $0.name == name }
        if let at {
            layers[at].bindings.removeAll { $0.lua == lua }
        }
        guard !combos.isEmpty, let template else { return }
        // Which layers exist where is the layer pass's alone (#2022):
        // a row never makes its layer.
        guard let at else {
            assertionFailure("row \(key) written where its layer is not")
            return
        }
        for combo in combos {
            var row = template
            row.combo = combo
            row.lua = lua
            if !combo.isEmpty {
                layers[at].bindings.removeAll { $0.combo == combo }
            }
            layers[at].bindings.append(row)
        }
    }

    /// Whether two layer lists carry the same shortcuts — names,
    /// icons and each row's combo and action, in order. Label and
    /// kind are presentation the import classifier rewrites.
    public static func sameShortcuts(_ a: [KeyLayer], _ b: [KeyLayer]) -> Bool
    {
        func shape(_ layers: [KeyLayer]) -> [[String]] {
            layers.map { layer in
                [layer.name, layer.icon ?? ""]
                    + layer.bindings.map { $0.combo + "\u{1F}" + $0.lua }
            }
        }
        return shape(a) == shape(b)
    }

    /// Each stored row, keyed as the key table keys it, for a row
    /// the save must write into a file that lacks it.
    public static func collectTemplates(
        _ layers: [KeyLayer],
        into templates: inout [String: KeyBinding]
    ) {
        for layer in layers {
            for row in layer.bindings where !row.lua.isEmpty {
                let key = keyID(
                    layer: layer.name,
                    lua: row.lua
                )
                if templates[key] == nil { templates[key] = row }
            }
        }
    }
}
