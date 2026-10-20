import KiwiDeskCore

/// Which bindings one shortcut row's ↺ takes back (#2412): the
/// pressed binding and every other changed binding of its layer
/// that its chords moved to or from, read from who holds each chord
/// now; never another layer's or an unchanged binding. The ↺ and
/// its words both read it. `layer` is the draft's name and `saved`
/// the name the baseline holds the layer under, which a rename
/// makes differ.
enum BindingRevertSet {
    /// The actions (`KeyBinding.lua`) the ↺ on `lua` takes back,
    /// `lua` first.
    static func walk(
        layer: String,
        saved: String,
        lua: String,
        draft: [KeyLayer],
        baseline: [KeyLayer]
    ) -> [String] {
        let now = rows(layer, in: draft)
        let was = rows(saved, in: baseline)
        func chords(_ action: String, _ rows: [KeyBinding]) -> Set<String> {
            Set(rows.filter { $0.lua == action }.map(\.combo))
                .subtracting([""])
        }
        let candidates = Set((now + was).map(\.lua)).filter {
            changed($0, now, was)
        }
        var set = [lua]
        var index = 0
        while index < set.count {
            let action = set[index]
            index += 1
            let wants = chords(action, was)
            let holds = chords(action, now)
            for other in candidates.sorted() where !set.contains(other) {
                let took = !wants.isDisjoint(with: chords(other, now))
                let lost = !holds.isDisjoint(with: chords(other, was))
                if took || lost { set.append(other) }
            }
        }
        return set
    }

    /// `draft` with `actions` of `layer` put back as `baseline`
    /// holds them under `saved`, each at its saved place; a draft
    /// row running the same action (`NavigationChords.sameAction`)
    /// goes too, so no action keeps a second chord.
    static func restore(
        _ actions: [String],
        layer: String,
        saved: String,
        draft: [KeyLayer],
        baseline: [KeyLayer]
    ) -> [KeyLayer] {
        guard let at = draft.firstIndex(where: { $0.name == layer }) else {
            return draft
        }
        let taken = Set(actions)
        let back = rows(saved, in: baseline).enumerated().filter {
            taken.contains($0.element.lua)
        }
        var layers = draft
        var bindings = layers[at].bindings.filter { row in
            !taken.contains(row.lua)
                && !back.contains {
                    NavigationChords.sameAction(row, $0.element)
                }
        }
        for (place, row) in back {
            bindings.insert(row, at: min(place, bindings.count))
        }
        layers[at].bindings = bindings
        return layers
    }

    /// `draft` with `lua`'s saved rows back in every layer whose
    /// saved copy holds them, each with its clash set — a lens's
    /// toggle or a layer's switch rows — and the reach keys of every
    /// action it put back, whose picks go with them. `saved` names a
    /// draft layer's saved name.
    static func restoreEverywhere(
        _ lua: String,
        draft: [KeyLayer],
        baseline: [KeyLayer],
        saved: (String) -> String
    ) -> (layers: [KeyLayer], keys: [String]) {
        var layers = draft
        var keys: [String] = []
        for layer in draft.map(\.name) {
            let name = saved(layer)
            guard rows(name, in: baseline).contains(where: { $0.lua == lua })
            else { continue }
            let set = walk(
                layer: layer,
                saved: name,
                lua: lua,
                draft: layers,
                baseline: baseline
            )
            layers = restore(
                set,
                layer: layer,
                saved: name,
                draft: layers,
                baseline: baseline
            )
            keys += set.map {
                RuleReachTable<String>.keyID(layer: layer, lua: $0)
            }
        }
        return (layers, keys)
    }

    private static func rows(
        _ layer: String,
        in layers: [KeyLayer]
    ) -> [KeyBinding] {
        layers.first { $0.name == layer }?.bindings ?? []
    }

    /// Whether the draft holds `lua`'s rows otherwise than saved.
    private static func changed(
        _ lua: String,
        _ now: [KeyBinding],
        _ saved: [KeyBinding]
    ) -> Bool {
        let mine = { (rows: [KeyBinding]) in
            rows.filter { $0.lua == lua }.map(\.combo).sorted()
        }
        return mine(now) != mine(saved)
    }
}
