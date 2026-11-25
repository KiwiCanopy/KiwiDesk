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
}
