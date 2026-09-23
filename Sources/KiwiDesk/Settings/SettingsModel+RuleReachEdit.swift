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

    /// The profiles the row ⚠ names, in menu order.
    var differing: [String] { profiles.filter { own[$0] != nil } }
}

extension SettingsModel {
    /// The checklist of a Space-list row; nil without a checklist.
    func spaceReach(_ app: String) -> RuleReachReading? {
        guard let reach = encodedReach else { return nil }
        return reading(reach.appRules, app, reach.unreadable) { $0.raw }
    }

    /// The checklist of a Float-list row, each other value
    /// described by `describe`.
    func floatReach(
        _ app: String,
        describe: ([String]) -> String
    ) -> RuleReachReading? {
        guard let reach = encodedReach else { return nil }
        return reading(reach.floatRules, app, reach.unreadable, describe)
    }

    /// Whether the column is drawn at all: a second profile to
    /// name, or a row that already differs.
    var offersReachColumn: Bool {
        guard let reach = encodedReach, let editing = reachProfile
        else { return false }
        if reach.appRules.profiles.count >= 2 { return true }
        return config.appRules.keys.contains {
            !reach.appRules.reach(of: $0.lowercased(), editing: editing)
                .isShared
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
        reachEdits.removal[family, default: [:]][app.lowercased()] = removal
    }

    // MARK: - Internals

    private func reading(
        _ family: RuleFamily,
        _ app: String
    ) -> RuleReachReading? {
        switch family {
        case .space: spaceReach(app)
        case .float: floatReach(app) { $0.joined(separator: ", ") }
        }
    }

    private func reading<V>(
        _ table: RuleReachTable<V>,
        _ app: String,
        _ unreadable: [String],
        _ describe: (V) -> String
    ) -> RuleReachReading? {
        guard let editing = reachProfile else { return nil }
        let key = app.lowercased()
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
            loaded: core.profiles.currentName,
            profiles: order + table.profiles.filter { !order.contains($0) },
            unreadable: unreadable,
            shared: table.follows(key, editing),
            users: Set(
                table.profiles.filter {
                    value != nil && table.resolved(key, for: $0) == value
                }
            ).union([editing]),
            own: own,
            ownIsShared: ownIsShared
        )
    }

    /// The reach a row has now: the draft's pick, else the shared
    /// or listed state the draft resolves to.
    private func reach(
        _ family: RuleFamily,
        _ app: String,
        row: RuleReachReading
    ) -> RuleReach {
        if let picked = reachEdits.reach[family]?[app.lowercased()] {
            return picked
        }
        return row.shared ? .shared(joining: []) : .listed(row.users)
    }

    private func setReach(
        _ family: RuleFamily,
        _ app: String,
        _ reach: RuleReach
    ) {
        reachEdits.reach[family, default: [:]][app.lowercased()] = reach
    }
}
