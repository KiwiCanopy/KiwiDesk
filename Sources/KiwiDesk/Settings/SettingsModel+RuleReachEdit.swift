import KiwiDeskCore

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
        let layer = RuleReachTable<String>.keyParts(key).layer
        if let layerRow = layerReach(layer) {
            row.lacking = Set(row.profiles).subtracting(layerRow.users)
            row.layerShared = layerRow.shared
        }
        return row
    }

    /// The checklist of a scroll-gesture row, keyed by
    /// `ScrollGestureField.rawValue` (#1656).
    func scrollReach(_ field: String) -> RuleReachReading? {
        guard let reach = encodedReach else { return nil }
        return reading(
            reach.scrollGestures,
            field,
            reach.unreadable,
            picked: reachEdits.reach[.scroll]?[field],
            ScrollGestureWords.value
        )
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
            // Named against THIS page's roster: a command only the
            // rival profile declares reads English (#2116).
            result[profile] =
                reach.keyTemplates[rival].map {
                    KeybindingCatalog.localizedName(of: $0, config: config)
                } ?? RuleReachTable<String>.keyParts(rival).lua
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
        // A row of a layer only some profiles have stays theirs: its
        // All profiles would bring the layer back everywhere (#2022).
        if on && !row.layerShared { return }
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
        // A box greyed for a missing layer is refused here too.
        if on && row.lacking.contains(profile) { return }
        switch reach(family, app, row: row) {
        case .shared(let joining):
            // A tick under All profiles is a join the Save has not made
            // yet, so it can be taken back — and a pick equal to the
            // row's own default is no pick at all.
            let now =
                on
                ? joining.union([profile]) : joining.subtracting([profile])
            if storedDefault(family, app) == .shared(joining: now) {
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
        case .scroll: scrollReach(app)
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

    /// The reach the draft encodes a row at when nothing is picked —
    /// the encoder's own `RuleReachDraft.defaultReach`, one copy.
    private func storedDefault(
        _ family: RuleFamily,
        _ app: String
    ) -> RuleReach? {
        guard let stored = layeredReach, let editing = reachProfile
        else { return nil }
        let key = family.key(app)
        switch family {
        case .space:
            return RuleReachDraft.defaultReach(
                of: key,
                in: stored.appRules,
                editing: editing,
                isLoaded: reachIsLoaded
            )
        case .float:
            return RuleReachDraft.defaultReach(
                of: key,
                in: stored.floatRules,
                editing: editing,
                isLoaded: reachIsLoaded
            )
        case .key:
            return RuleReachDraft.defaultReach(
                of: key,
                in: stored.keyLayers,
                editing: editing,
                isLoaded: reachIsLoaded
            )
        case .scroll:
            return RuleReachDraft.defaultReach(
                of: key,
                in: stored.scrollGestures,
                editing: editing,
                isLoaded: reachIsLoaded
            )
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
