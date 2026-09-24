import KiwiDeskCore

/// One App Rules row's "Applies to" checklist, read off the draft
/// (#1393). Every tick, ⚠ and label is relative to `editing`.
struct RuleReachReading: Equatable {
    let editing: String
    let loaded: String?
    /// Every readable profile, in the edit-target menu's order.
    let profiles: [String]
    let unreadable: [String]
    /// Whether the row is the shared rule.
    let shared: Bool
    /// The profiles that resolve this row's value, `editing` too.
    let users: Set<String>
    /// Profiles resolving a DIFFERENT value, in its words.
    let own: [String: String]
    /// Those of `own` whose value is the shared rule.
    let ownIsShared: Set<String>
    /// Profiles that leave this shared rule out.
    let leftOut: Set<String>
    /// A shortcut's combo that another profile binds to a
    /// different action, in that action's words — ticking takes
    /// the key over.
    var takenBy: [String: String] = [:]

    /// Whether `profile`'s box is the edited profile's, locked.
    func isLocked(_ profile: String) -> Bool { profile == editing }

    /// Whether `profile`'s box follows All profiles — ticked and
    /// greyed. One with its own value, or left out, stays
    /// tickable, which drops that value.
    func follows(_ profile: String) -> Bool {
        shared && own[profile] == nil && !leftOut.contains(profile)
    }

    /// The profiles the row ⚠ names, in menu order.
    var differing: [String] {
        profiles.filter { own[$0] != nil || leftOut.contains($0) }
    }
}

extension SettingsModel {
    /// The checklist of a Space-list row; nil without a checklist.
    func spaceReach(_ app: String) -> RuleReachReading? {
        guard let reach = encodedReach else { return nil }
        return reading(reach.appRules, app.lowercased(), reach.unreadable) {
            $0.raw
        }
    }

    /// The checklist of a Float-list row, each other value
    /// described by `describe`.
    func floatReach(
        _ app: String,
        describe: ([String]) -> String
    ) -> RuleReachReading? {
        guard let reach = encodedReach else { return nil }
        return reading(
            reach.floatRules,
            app.lowercased(),
            reach.unreadable,
            describe
        )
    }

    /// The checklist of a shortcut row, keyed by
    /// `RuleReachTable.keyID`.
    func keyReach(_ key: String) -> RuleReachReading? {
        guard let reach = encodedReach,
            var row = reading(
                reach.keyLayers,
                key,
                reach.unreadable,
                { ShortcutsReferenceBuilder.glyphs($0) }
            )
        else { return nil }
        row.takenBy = keyTakers(key, in: reach, editing: row.editing)
        return row
    }

    /// Who binds this row's combo to another action, per profile.
    private func keyTakers(
        _ key: String,
        in reach: RuleReachSnapshot,
        editing: String
    ) -> [String: String] {
        guard let combo = reach.keyLayers.resolved(key, for: editing),
            !combo.isEmpty
        else { return [:] }
        let (layer, lua) = RuleReachTable<String>.keyParts(key)
        var result: [String: String] = [:]
        for profile in reach.keyLayers.profiles where profile != editing {
            let layers =
                reach.storedKeyOverrides[profile]?.resolved(
                    onto: reach.storedKeyBase
                ) ?? reach.storedKeyBase
            let taker = layers.first { $0.name == layer }?.bindings
                .first { $0.combo == combo && $0.lua != lua }
            if let taker {
                result[profile] = taker.label.isEmpty ? taker.lua : taker.label
            }
        }
        return result
    }

    /// Whether the column is drawn at all: a profile loaded, and
    /// a second profile to name or a row that already differs.
    var offersReachColumn: Bool {
        guard reachLoaded != nil,
            let reach = encodedReach, let editing = reachProfile
        else { return false }
        if reach.appRules.profiles.count >= 2 { return true }
        let spaces = reach.appRules.resolved(for: editing).keys
        let floats = reach.floatRules.resolved(for: editing).keys
        return spaces.contains {
            !reach.appRules.reach(of: $0, editing: editing).isShared
        }
            || floats.contains {
                !reach.floatRules.reach(of: $0, editing: editing).isShared
            }
    }

    /// Ticks or unticks "All profiles" on a row.
    func setAllProfiles(_ family: RuleFamily, _ app: String, _ on: Bool) {
        guard let row = reading(family, app) else { return }
        let others = row.users.subtracting([row.editing])
        setReach(
            family,
            app,
            on ? .shared(joining: others) : .listed(row.users)
        )
    }

    /// Ticks or unticks one profile on a row. Under All profiles
    /// only a profile with its own value is tickable, and ticking
    /// it drops that value.
    func setProfile(
        _ family: RuleFamily,
        _ app: String,
        _ profile: String,
        _ on: Bool
    ) {
        guard let row = reading(family, app), profile != row.editing
        else { return }
        switch reach(family, app, row: row) {
        case .shared(let joining):
            guard on else { return }
            setReach(family, app, .shared(joining: joining.union([profile])))
        case .listed:
            let users =
                on
                ? row.users.union([profile]) : row.users.subtracting([profile])
            setReach(family, app, .listed(users))
        }
    }

    /// Records how a removal the trash is about to make reaches.
    func recordRemoval(
        _ family: RuleFamily,
        _ app: String,
        _ removal: RuleRemoval
    ) {
        reachEdits.removal[family, default: [:]][family.key(app)] = removal
    }

    // MARK: - Internals

    private func reading(
        _ family: RuleFamily,
        _ app: String
    ) -> RuleReachReading? {
        switch family {
        case .space: spaceReach(app)
        case .float: floatReach(app) { $0.joined(separator: ", ") }
        case .key: keyReach(app)
        }
    }

    private func reading<V>(
        _ table: RuleReachTable<V>,
        _ app: String,
        _ unreadable: [String],
        _ describe: (V) -> String
    ) -> RuleReachReading? {
        guard let editing = reachProfile else { return nil }
        let key = app
        let value = table.resolved(key, for: editing)
        var own: [String: String] = [:]
        var ownIsShared: Set<String> = []
        for profile in table.profiles where profile != editing {
            guard let other = table.resolved(key, for: profile),
                other != value
            else { continue }
            own[profile] = describe(other)
            if table.follows(key, profile) { ownIsShared.insert(profile) }
        }
        let order = profileMenuOrder.filter(table.profiles.contains)
        return RuleReachReading(
            editing: editing,
            loaded: reachLoaded,
            profiles: order + table.profiles.filter { !order.contains($0) },
            unreadable: unreadable,
            shared: table.follows(key, editing),
            users: Set(
                table.profiles.filter {
                    value != nil && table.resolved(key, for: $0) == value
                }
            ).union([editing]),
            own: own,
            ownIsShared: ownIsShared,
            // Only the shared rule's own row names who left it out.
            leftOut: table.follows(key, editing)
                ? Set(table.leftOut(key)).subtracting([editing]) : []
        )
    }

    /// The reach a row has now: the draft's pick, else the shared
    /// or listed state the draft resolves to.
    private func reach(
        _ family: RuleFamily,
        _ app: String,
        row: RuleReachReading
    ) -> RuleReach {
        if let picked = reachEdits.reach[family]?[family.key(app)] {
            return picked
        }
        return row.shared ? .shared(joining: []) : .listed(row.users)
    }

    private func setReach(
        _ family: RuleFamily,
        _ app: String,
        _ reach: RuleReach
    ) {
        reachEdits.reach[family, default: [:]][family.key(app)] = reach
    }
}
