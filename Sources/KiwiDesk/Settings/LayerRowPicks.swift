import KiwiDeskCore

/// The one owner of a layer name's lifecycle in a draft's row picks
/// (#2022): a shortcut row's reach and removal are keyed
/// `layer␟lua`, so a layer renamed, deleted or narrowed moves,
/// drops or trims them here — or a stale pick reaches past the
/// layer edit at Save.
@MainActor
enum LayerRowPicks {
    /// The picks of `old`'s rows, and of rows switching to it,
    /// follow the new name.
    static func renamed(
        _ edits: inout RuleReachEdits,
        from old: String,
        to new: String
    ) {
        let oldSwitch = KeybindingCatalog.switchLayerCommand(old).lua
        let newSwitch = KeybindingCatalog.switchLayerCommand(new).lua
        func rekey<V>(_ map: [String: V]?) -> [String: V]? {
            map.map { map in
                var result: [String: V] = [:]
                for (key, value) in map {
                    var (layer, lua) = RuleReachTable<String>.keyParts(key)
                    if layer == old { layer = new }
                    if lua == oldSwitch { lua = newSwitch }
                    let id = RuleReachTable<String>.keyID(
                        layer: layer,
                        lua: lua
                    )
                    result[id] = value
                }
                return result
            }
        }
        edits.reach[.key] = rekey(edits.reach[.key])
        edits.removal[.key] = rekey(edits.removal[.key])
    }

    /// A deleted layer takes its rows' picks, and those of rows
    /// switching to it — the layer pass decides where they go.
    static func deleted(_ edits: inout RuleReachEdits, layer: String) {
        let switchTo = KeybindingCatalog.switchLayerCommand(layer).lua
        func gone(_ key: String) -> Bool {
            let parts = RuleReachTable<String>.keyParts(key)
            return parts.layer == layer || parts.lua == switchTo
        }
        edits.reach[.key] = edits.reach[.key]?.filter { !gone($0.key) }
        edits.removal[.key] = edits.removal[.key]?.filter { !gone($0.key) }
    }

    /// A row pick names only profiles that hold its layer: a tick
    /// left on a profile the layer leaves would rebuild a layer of
    /// one row there.
    static func keep(
        _ edits: inout RuleReachEdits,
        layer: String,
        holders: Set<String>
    ) {
        guard var picks = edits.reach[.key] else { return }
        for (key, reach) in picks
        where RuleReachTable<String>.keyParts(key).layer == layer {
            switch reach {
            case .listed(let members):
                picks[key] = .listed(members.intersection(holders))
            case .shared(let joining):
                picks[key] = .shared(joining: joining.intersection(holders))
            }
        }
        edits.reach[.key] = picks
    }
}
