import Foundation

// The shortcut base a key table writes (#1393): from the stored
// base for a stored page, from the loaded page for the live one.

extension RuleReachTable where Value == String {
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

    /// The base as a LOADED page's layers hold it: the layered
    /// stored base's layers, each the page's copy where the page
    /// has it; each key patched to the table's base, and an icon the
    /// page left alone taken from the base.
    public func keyLayerBase(
        page: [KeyLayer],
        editing: String,
        storedPage: [KeyLayer],
        storedBase: [KeyLayer],
        templates: [String: KeyBinding]
    ) -> [KeyLayer] {
        // The base's layer SET and order are the layered stored
        // base's, decided by the layer pass alone (#2022): the page
        // supplies a layer's copy, never a layer.
        var layers = storedBase.map { shared in
            page.first { $0.name == shared.name } ?? shared
        }
        for at in layers.indices {
            let name = layers[at].name
            guard let shared = storedBase.first(where: { $0.name == name }),
                let stored = storedPage.first(where: { $0.name == name }),
                layers[at].icon == stored.icon
            else { continue }
            layers[at].icon = shared.icon
        }
        // An untouched action's rows are the page's, minus the ones
        // its profile's OWN override added and plus the shared ones
        // it left out or rebound — so a combo the profile moved
        // stays its own, while an edit to a second shared combo
        // lands. A touched action's row is the table's, and one
        // the page's profile alone changed keeps the stored base.
        let held = Self.allCombos(layers)
        let storedPage = Self.allCombos(storedPage)
        let stored = Self.allCombos(storedBase)
        for key in Set(held.keys).union(stored.keys).union(baseTouched)
            .sorted()
        {
            var target: [String]
            if baseTouched.contains(key) {
                target = base[key].map { [$0] } ?? []
            } else if touched[editing]?.contains(key) == true {
                target = stored[key] ?? []
            } else {
                target = held[key] ?? []
                var own = storedPage[key] ?? []
                var dropped: [String] = []
                for combo in stored[key] ?? [] {
                    if let at = own.firstIndex(of: combo) {
                        own.remove(at: at)
                    } else {
                        dropped.append(combo)
                    }
                }
                target.removeAll { own.contains($0) }
                target += dropped.filter { !target.contains($0) }
            }
            if held[key] ?? [] != target {
                Self.setRows(&layers, key, target, templates[key])
            }
        }
        return layers
    }
}
