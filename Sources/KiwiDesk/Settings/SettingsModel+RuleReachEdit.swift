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
            FloatRules.appKey(app),
            reach.unreadable,
            picked: reachEdits.reach[.float]?[FloatRules.appKey(app)],
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
                Self.keyValueWords
            )
        else { return nil }
        let takers = keyTakers(key, editing: row.editing)
        row.takenBy = takers.names
        row.clashing = takers.clashing
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

    /// The Space history row's checklist (#1655).
    func historyReach() -> RuleReachReading? {
        guard let reach = encodedReach else { return nil }
        let key = RuleReachTable<SpaceHistoryKind>.spaceHistoryKey
        return reading(
            reach.spaceHistory,
            key,
            reach.unreadable,
            picked: reachEdits.reach[.history]?[key],
            SpaceHistoryWords.value
        )
    }

    /// Who binds this row's chord to another key, per profile, read
    /// off the encoded table — the one ticking would take the chord
    /// from — and where that is refused: a key sequence on either
    /// side, which a tick never takes nor loses (#3124 ▸ Ruling 1).
    private func keyTakers(
        _ key: String,
        editing: String
    ) -> (names: [String: String], clashing: Set<String>) {
        guard let reach = encodedReach, let rivals = encodedKeyRivals
        else { return ([:], []) }
        let table = reach.keyLayers
        guard let value = table.resolved(key, for: editing), !value.isEmpty
        else { return ([:], []) }
        let combo = RuleReachTable<String>.chord(of: key, value: value)
        var names: [String: String] = [:]
        var clashing: Set<String> = []
        for profile in table.profiles where profile != editing {
            guard let rival = rivals.rival(of: key, for: profile, combo: combo)
            else { continue }
            names[profile] = keyName(rival, templates: reach.keyTemplates)
            if RuleReachTable<String>.clashes(key, rival) {
                clashing.insert(profile)
            }
        }
        return (names, clashing)
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
        let tiles = reach.tileRules.resolved(for: editing).keys
        let automatic = RuleReachTable<Bool>.floatAutomaticallyKey
        return spaces.contains {
            !reach.appRules.reach(of: $0, editing: editing).isShared
        }
            || floats.contains {
                !reach.floatRules.reach(of: $0, editing: editing).isShared
            }
            || tiles.contains {
                !reach.tileRules.reach(of: $0, editing: editing).isShared
            }
            || !reach.floatAutomatically.reach(
                of: automatic,
                editing: editing
            ).isShared
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
        // A box greyed for a missing layer, or for a chord a key
        // sequence clashes on, is refused here too.
        let refused =
            row.lacking.contains(profile) || row.clashing.contains(profile)
        if on && refused { return }
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

    /// Moves the reach `old` has now — picked or stored — to `new`,
    /// a pick equal to `new`'s own default being no pick (#3124).
    func carryPick(_ family: RuleFamily, from old: String, to new: String) {
        guard let row = reading(family, old) else { return }
        let carried = reach(family, old, row: row)
        reachEdits.reach[family]?[family.key(old)] = nil
        reachEdits.removal[family]?[family.key(old)] = nil
        if storedDefault(family, new) == carried {
            reachEdits.reach[family]?[family.key(new)] = nil
        } else {
            setReach(family, new, carried)
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
        case .gesture: gestureReach(app)
        case .history: historyReach()
        case .wrap: wrapReach()
        case .cycle: cycleReach()
        case .tile: tileReach(app)
        case .autoFloat: autoFloatReach()
        case .tilingStart: tilingStartReach()
        case .tilingOffHides: tilingOffHidesReach(app)
        }
    }

    func reading<V>(
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

    func setReach(
        _ family: RuleFamily,
        _ app: String,
        _ reach: RuleReach
    ) {
        reachEdits.reach[family, default: [:]][family.key(app)] = reach
    }
}
