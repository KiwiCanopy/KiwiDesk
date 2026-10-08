import KiwiDeskCore

/// Which profiles a keyboard layer belongs to (#2022): the draft's
/// layer edits laid over the stored files, and the "Applies to"
/// reading of one layer. A layer's tick IS membership.
extension SettingsModel {
    /// The "Applies to" reading of the page's layer `name`.
    func layerReach(
        _ name: String,
        edits: RuleReachEdits? = nil
    ) -> RuleReachReading? {
        guard let reach = layeredReach(edits ?? reachEdits),
            let editing = reachProfile
        else { return nil }
        let table = reach.layerTable
        let everyone = table.profiles
        let order = profileMenuOrder.filter(everyone.contains)
        let known =
            table.base[name] != nil
            || everyone.contains { table.resolved(name, for: $0) != nil }
        let shared =
            known
            ? table.base[name] != nil
            : RuleReachDraft.defaultReach(
                of: name,
                in: table,
                editing: editing,
                isLoaded: reachIsLoaded
            ).isShared
        let users =
            known
            ? Set(everyone.filter { table.resolved(name, for: $0) != nil })
            : (shared ? Set(everyone) : [])
        let page = config.layers.first { $0.name == name }
        var own: [String: String] = [:]
        for profile in users where profile != editing {
            let theirs = reach.storedKeyLayers(for: profile)
                .first { $0.name == name }
            if !Self.sameRows(theirs, page) {
                own[profile] = L(
                    "shortcuts.layer_reach.differs",
                    "⚠ Some shortcuts differ"
                )
            }
        }
        return RuleReachReading(
            editing: editing,
            loaded: reachLoaded,
            profiles: order + everyone.filter { !order.contains($0) },
            unreadable: reach.unreadable,
            shared: shared,
            hasShared: shared,
            users: users.union([editing]),
            own: own,
            ownIsShared: [],
            leftOut: shared
                ? Set(everyone).subtracting(users).subtracting([editing])
                : []
        )
    }

    /// Ticks or unticks one profile: it gains the layer, or the
    /// layer leaves it at Save.
    func setLayerProfile(_ name: String, _ profile: String, _ on: Bool) {
        guard let row = layerReach(name), profile != row.editing else {
            return
        }
        let users =
            on ? row.users.union([profile]) : row.users.subtracting([profile])
        pickMembers(name, LayerMembers(shared: row.shared, profiles: users))
    }

    /// Ticks or unticks All profiles: every profile, and every one
    /// created later — or the profiles that have it now, alone.
    func setLayerAllProfiles(_ name: String, _ on: Bool) {
        guard let row = layerReach(name) else { return }
        pickMembers(
            name,
            LayerMembers(
                shared: on,
                profiles: on ? Set(row.profiles) : row.users
            )
        )
    }

    // MARK: - Internals

    private func pickMembers(_ name: String, _ members: LayerMembers) {
        var edits = reachEdits
        var edit = edits.layers[name] ?? LayerEdit(stored: storedLayer(name))
        edit.members = nil
        edits.layers[name] = edit
        // A pick equal to what the layer has without it is no pick.
        let before = layerReach(name, edits: edits)
        if before?.shared != members.shared
            || before?.users != members.profiles
        {
            edit.members = members
        }
        edits.layers[name] = edit.isInert(at: name) ? nil : edit
        LayerRowPicks.keep(
            &edits,
            layer: name,
            holders: (edit.members?.profiles ?? before?.users ?? [])
                .union(reachProfile.map { [$0] } ?? [])
        )
        reachEdits = edits
    }

    /// The name `name` is stored under: its edit's, else its own
    /// where a profile or the base holds it and no edit or delete of
    /// the draft already claims that stored layer. nil for a layer
    /// the draft created — a new layer is always new.
    func storedLayer(_ name: String) -> String? {
        if let edit = reachEdits.layers[name] { return edit.stored }
        guard reachEdits.deletedLayers[name] == nil,
            !reachEdits.layers.values.contains(where: { $0.stored == name }),
            let table = ruleReachStored?.layerTable
        else { return nil }
        let held =
            table.base[name] != nil
            || table.profiles.contains { table.resolved(name, for: $0) != nil }
        return held ? name : nil
    }

    /// Whether a stored page leaves `name` to the loaded page: it
    /// is shared, judged on the STORED files so a tick in the open
    /// popover cannot lock the control under the user.
    func layerLockedHere(_ name: String) -> Bool {
        guard editingProfile != nil else { return false }
        guard let table = ruleReachStored?.layerTable else {
            return profileEditingBaseLayers?.contains { $0.name == name }
                ?? false
        }
        guard let stored = storedLayer(name) else { return false }
        let holders = table.profiles.filter {
            table.resolved(stored, for: $0) != nil
        }
        return table.base[stored] != nil || holders.count > 1
    }

    /// Whether two copies of a layer bind the same combos to the
    /// same actions, whatever their order.
    static func sameRows(_ a: KeyLayer?, _ b: KeyLayer?) -> Bool {
        func rows(_ layer: KeyLayer?) -> [String] {
            (layer?.bindings ?? []).map { $0.combo + "\u{1F}" + $0.lua }
                .sorted()
        }
        return rows(a) == rows(b)
    }
}
