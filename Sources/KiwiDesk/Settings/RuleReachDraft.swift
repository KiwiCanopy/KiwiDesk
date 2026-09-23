import KiwiDeskCore

/// The two App Rules families an "Applies to" checklist edits
/// (#1393).
enum RuleFamily: Hashable {
    case space
    case float
}

/// The checklist choices a draft holds over the stored rules
/// (#1393): per family, the reach picked for an app and how a
/// removal reached. Values stay the draft config's; this holds
/// only who they reach, so a later value edit lands on the same
/// profiles.
struct RuleReachEdits: Equatable {
    var reach: [RuleFamily: [String: RuleReach]] = [:]
    var removal: [RuleFamily: [String: RuleRemoval]] = [:]

    var isEmpty: Bool {
        reach.values.allSatisfy(\.isEmpty)
            && removal.values.allSatisfy(\.isEmpty)
    }
}

/// Pure encoding of a draft onto the stored table: every app the
/// draft touched is re-applied from the edited profile's page.
enum RuleReachDraft {
    /// The reach an app has before the user picks one: its stored
    /// reach, or for a NEW rule, shared on the loaded profile and
    /// the edited profile alone on a stored one.
    static func defaultReach<V>(
        of key: String,
        in stored: RuleReachTable<V>,
        editing: String,
        isLoaded: Bool
    ) -> RuleReach {
        if stored.resolved(key, for: editing) != nil {
            return stored.reach(of: key, editing: editing)
        }
        return isLoaded ? .shared(joining: []) : .listed([editing])
    }

    /// `stored` with the draft applied: `current` is the edited
    /// profile's values as the page holds them.
    static func encode<V>(
        _ stored: RuleReachTable<V>,
        current: [String: V],
        editing: String,
        isLoaded: Bool,
        reach: [String: RuleReach],
        removal: [String: RuleRemoval]
    ) -> RuleReachTable<V> {
        var table = stored
        let keys = Set(current.keys)
            .union(stored.resolved(for: editing).keys)
            .union(reach.keys)
            .union(removal.keys)
        for key in keys.sorted() {
            let value = current[key]
            let picked = reach[key]
            guard
                picked != nil || removal[key] != nil
                    || value != stored.resolved(key, for: editing)
            else { continue }
            table.apply(
                key,
                value: value,
                reach: picked
                    ?? defaultReach(
                        of: key,
                        in: stored,
                        editing: editing,
                        isLoaded: isLoaded
                    ),
                removal: removal[key] ?? .everywhere,
                editing: editing
            )
        }
        return table
    }
}
