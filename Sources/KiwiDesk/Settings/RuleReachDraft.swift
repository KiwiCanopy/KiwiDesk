import KiwiDeskCore

/// The rule families an "Applies to" checklist edits (#1393).
enum RuleFamily: Hashable {
    case space
    case float
    /// A shortcut: one action in one layer, keyed by
    /// `RuleReachTable.keyID`.
    case key
    /// A scroll-gesture setting, keyed by `ScrollGestureField`
    /// (#1656).
    case scroll

    /// How a row's subject keys its table: app rules by the
    /// lowercased bundle id, a shortcut's action and a scroll
    /// setting verbatim.
    func key(_ subject: String) -> String {
        switch self {
        case .key, .scroll: subject
        case .space, .float: subject.lowercased()
        }
    }
}

/// The checklist choices a draft holds over the stored rules
/// (#1393): per family, the reach picked for an app and how a
/// removal reached. Values stay the draft config's; this holds
/// only who they reach, so a later value edit lands on the same
/// profiles.
struct RuleReachEdits: Equatable {
    var reach: [RuleFamily: [String: RuleReach]] = [:]
    var removal: [RuleFamily: [String: RuleRemoval]] = [:]
    /// Layer edits (#2022), keyed by the layer's name on the page.
    var layers: [String: LayerEdit] = [:]
    /// Stored layers the draft deleted, and how far.
    var deletedLayers: [String: RuleRemoval] = [:]

    var isEmpty: Bool {
        reach.values.allSatisfy(\.isEmpty)
            && removal.values.allSatisfy(\.isEmpty)
            && layers.isEmpty && deletedLayers.isEmpty
    }
}

/// One layer's draft edit (#2022): the name it is stored under,
/// nil for a layer the draft created, and the profiles picked to
/// hold it.
struct LayerEdit: Equatable {
    var stored: String?
    var members: LayerMembers?

    /// Whether the edit changes nothing a Save would write.
    func isInert(at name: String) -> Bool {
        members == nil && (stored == nil || stored == name)
    }
}

/// Who holds a layer: the shared base (every profile created later
/// too) or not, and the profiles that have it.
struct LayerMembers: Equatable {
    var shared: Bool
    var profiles: Set<String>
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
        removal: [String: RuleRemoval],
        apply: (
            inout RuleReachTable<V>, String, V?, RuleReach, RuleRemoval,
            String
        ) -> Void = {
            $0.apply($1, value: $2, reach: $3, removal: $4, editing: $5)
        }
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
            apply(
                &table,
                key,
                value,
                picked
                    ?? defaultReach(
                        of: key,
                        in: stored,
                        editing: editing,
                        isLoaded: isLoaded
                    ),
                removal[key] ?? .everywhere,
                editing
            )
        }
        return table
    }
}
