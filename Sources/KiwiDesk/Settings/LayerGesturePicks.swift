import KiwiDeskCore

/// The gesture rows' picks of a renamed or deleted layer (#3535),
/// keyed by `LayerGestureKey` spelling as the gesture reach table
/// keys a row: the `LayerRowPicks` of the gesture family.
enum LayerGesturePicks {
    /// The picks of `old`'s gesture rows follow the new name.
    static func renamed(
        _ edits: inout RuleReachEdits,
        from old: String,
        to new: String
    ) {
        func rekey<V>(_ map: [String: V]?) -> [String: V]? {
            map.map { map in
                var result: [String: V] = [:]
                for (spelling, value) in map {
                    guard let key = LayerGestureKey(spelling: spelling),
                        key.layer == old
                    else {
                        result[spelling] = value
                        continue
                    }
                    result[LayerGestureKey(new, key.key).spelling] = value
                }
                return result
            }
        }
        edits.reach[.gesture] = rekey(edits.reach[.gesture])
        edits.removal[.gesture] = rekey(edits.removal[.gesture])
    }

    /// A deleted layer takes its gesture rows' picks.
    static func deleted(_ edits: inout RuleReachEdits, layer: String) {
        func gone(_ spelling: String) -> Bool {
            LayerGestureKey(spelling: spelling)?.layer == layer
        }
        edits.reach[.gesture] =
            edits.reach[.gesture]?.filter { !gone($0.key) }
        edits.removal[.gesture] =
            edits.removal[.gesture]?.filter { !gone($0.key) }
    }

    /// A gesture pick on a layer other than `default` names only
    /// the layer's holders, as `LayerRowPicks.keep` does for keys: a
    /// tick left on a profile the layer leaves would write its map
    /// back there.
    static func keep(
        _ edits: inout RuleReachEdits,
        layer: String,
        holders: Set<String>,
        shared: Bool
    ) {
        guard layer != KeyLayer.defaultName,
            var picks = edits.reach[.gesture]
        else { return }
        for (spelling, reach) in picks
        where LayerGestureKey(spelling: spelling)?.layer == layer {
            switch reach {
            case .listed(let members):
                picks[spelling] = .listed(members.intersection(holders))
            case .shared(let joining):
                picks[spelling] =
                    shared
                    ? .shared(joining: joining.intersection(holders))
                    : .listed(holders)
            }
        }
        edits.reach[.gesture] = picks
    }

    /// The gesture picks the encode takes, as `LayerRowPicks.scoped`
    /// for keys: in a layer the base does not share, a new row
    /// starts on the layer's holders and a shared pick is theirs, so
    /// no row writes the layer's map into the shared base.
    static func scoped(
        _ picks: [String: RuleReach],
        page: [String: GestureAction],
        layers: RuleReachTable<Bool>,
        gestures: RuleReachTable<GestureAction>,
        editing: String,
        isLoaded: Bool
    ) -> [String: RuleReach] {
        var result = picks
        for spelling in Set(page.keys).union(picks.keys) {
            guard let layer = LayerGestureKey(spelling: spelling)?.layer,
                layer != KeyLayer.defaultName,
                layers.base[layer] == nil
            else { continue }
            let holders = Set(
                layers.profiles.filter {
                    layers.resolved(layer, for: $0) != nil
                }
            ).union([editing])
            switch picks[spelling] {
            case .shared?:
                result[spelling] = .listed(holders)
            case nil
            where isLoaded
                && gestures.resolved(spelling, for: editing) == nil:
                result[spelling] = .listed(holders)
            default:
                break
            }
        }
        return result
    }
}
