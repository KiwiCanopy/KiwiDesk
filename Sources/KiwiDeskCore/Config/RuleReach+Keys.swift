import Foundation

// Shortcuts as a `RuleReachTable` (#1393): a key is one action in
// one layer, its value the combo. `KeyLayerOverride` replaces per
// combo and cannot delete, so this family never stores a left-out
// mark — `removeCarrying` spells "not here" instead — and a row
// written into a profile takes its combo over from whatever that
// profile bound there.

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

    /// The base layers: `original` with each touched key's row
    /// rebuilt from `templates`.
    public func keyLayerBase(
        original: [KeyLayer],
        templates: [String: KeyBinding]
    ) -> [KeyLayer] {
        var layers = original
        for key in baseTouched.sorted() {
            Self.set(&layers, key, base[key], templates[key])
        }
        return layers
    }

    /// The base as a LOADED page's layers hold it: the page's
    /// layers, order and structure, each key patched to the table's
    /// base, a layer only the page profile's own override carried
    /// dropped unless a shared row now lives in it, and an icon the
    /// page left alone taken from the base.
    public func keyLayerBase(
        page: [KeyLayer],
        storedPage: [KeyLayer],
        storedBase: [KeyLayer],
        templates: [String: KeyBinding]
    ) -> [KeyLayer] {
        let baseNames = Set(storedBase.map(\.name))
        let sharedLayers = Set(base.keys.map { Self.keyParts($0).layer })
        let pageOwn = Set(storedPage.map(\.name)).subtracting(baseNames)
        var layers = page.filter { layer in
            !pageOwn.contains(layer.name) || sharedLayers.contains(layer.name)
        }
        for at in layers.indices {
            let name = layers[at].name
            guard let shared = storedBase.first(where: { $0.name == name }),
                let stored = storedPage.first(where: { $0.name == name }),
                layers[at].icon == stored.icon
            else { continue }
            layers[at].icon = shared.icon
        }
        let held = Self.combos(layers)
        for key in Set(held.keys).union(base.keys).sorted()
        where held[key] != base[key] {
            Self.set(&layers, key, base[key], templates[key])
        }
        return layers
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
        let (name, lua) = keyParts(key)
        var at = layers.firstIndex { $0.name == name }
        if let at {
            layers[at].bindings.removeAll { $0.lua == lua }
        }
        guard let combo, var row = template else { return }
        row.combo = combo
        row.lua = lua
        if at == nil {
            layers.append(KeyLayer(name: name))
            at = layers.count - 1
        }
        guard let at else { return }
        if !combo.isEmpty {
            layers[at].bindings.removeAll { $0.combo == combo }
        }
        layers[at].bindings.append(row)
    }
}
