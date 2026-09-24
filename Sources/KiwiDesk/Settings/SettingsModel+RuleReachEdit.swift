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
    var shared: Bool
    /// Whether a shared rule exists for this row's subject, which a
    /// profile created later inherits.
    let hasShared: Bool
    /// The profiles that resolve this row's value, `editing` too —
    /// or, while a picked list waits for a value, the ticked ones.
    var users: Set<String>
    /// Profiles resolving a DIFFERENT value, in its words.
    let own: [String: String]
    /// Those of `own` whose value is the shared rule.
    let ownIsShared: Set<String>
    /// Profiles that leave this shared rule out.
    var leftOut: Set<String>
    /// Profiles the draft's pick ticked into the shared rule — still
    /// tickable until the Save, so a tick can be taken back.
    var joined: Set<String> = []
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
            && !joined.contains(profile)
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
        return reading(
            reach.appRules,
            app.lowercased(),
            reach.unreadable,
            picked: reachEdits.reach[.space]?[app.lowercased()]
        ) { $0.raw }
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
            picked: reachEdits.reach[.float]?[app.lowercased()],
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
                picked: reachEdits.reach[.key]?[key],
                { ShortcutsReferenceBuilder.glyphs($0) }
            )
        else { return nil }
        row.takenBy = keyTakers(key, in: reach, editing: row.editing)
        return row
    }

    /// Who binds this row's combo to another action, per profile,
    /// read off the encoded table — the action ticking would take
    /// the key from.
    private func keyTakers(
        _ key: String,
        in reach: RuleReachSnapshot,
        editing: String
    ) -> [String: String] {
        let table = reach.keyLayers
        guard let combo = table.resolved(key, for: editing), !combo.isEmpty
        else { return [:] }
        var result: [String: String] = [:]
        for profile in table.profiles where profile != editing {
            guard let rival = table.rival(of: key, for: profile, combo: combo)
            else { continue }
            let label = reach.keyTemplates[rival]?.label ?? ""
            result[profile] =
                label.isEmpty
                ? RuleReachTable<String>.keyParts(rival).lua : label
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
            // A tick under All profiles is a join the Save has not made
            // yet, so it can be taken back — and taking the last one
            // back on a row stored shared leaves no pick at all.
            let now =
                on
                ? joining.union([profile]) : joining.subtracting([profile])
            if now.isEmpty, storedIsShared(family, app) {
                reachEdits.reach[family]?[family.key(app)] = nil
            } else {
                setReach(family, app, .shared(joining: now))
            }
        case .listed(let members):
            let users =
                on ? members.union([profile]) : members.subtracting([profile])
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
        picked: RuleReach?,
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
        var row = RuleReachReading(
            editing: editing,
            loaded: reachLoaded,
            profiles: order + table.profiles.filter { !order.contains($0) },
            unreadable: unreadable,
            shared: table.follows(key, editing),
            hasShared: table.base[key] != nil,
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
        // A picked list the draft has not given a value yet changes
        // nothing in the table, so the ticks read the pick.
        if case .listed(let members) = picked {
            row.shared = false
            row.users = members.union([editing])
            row.leftOut = []
        }
        if case .shared(let joining) = picked { row.joined = joining }
        return row
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

    /// Whether the row reads shared in the STORED files, before any
    /// pick of the draft.
    private func storedIsShared(_ family: RuleFamily, _ app: String) -> Bool {
        guard let stored = ruleReachStored, let editing = reachProfile
        else { return false }
        let key = family.key(app)
        switch family {
        case .space: return stored.appRules.follows(key, editing)
        case .float: return stored.floatRules.follows(key, editing)
        case .key: return stored.keyLayers.follows(key, editing)
        }
    }

    private func setReach(
        _ family: RuleFamily,
        _ app: String,
        _ reach: RuleReach
    ) {
        reachEdits.reach[family, default: [:]][family.key(app)] = reach
    }
}
