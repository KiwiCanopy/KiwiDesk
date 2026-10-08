import KiwiDeskCore

/// Which profiles a keyboard layer belongs to (#2022): the draft's
/// layer edits laid over the stored files, and the "Applies to"
/// reading of one layer. A layer's tick IS membership.
extension SettingsModel {
    /// The stored rules with the draft's layer edits laid over the
    /// shortcut files — what the key table encodes row edits
    /// against. nil without a checklist.
    var layeredReach: RuleReachSnapshot? {
        layeredReach(reachEdits)
    }

    func layeredReach(_ edits: RuleReachEdits) -> RuleReachSnapshot? {
        guard var snapshot = ruleReachStored, let editing = reachProfile
        else { return ruleReachStored }
        let everyone = snapshot.keyLayers.profiles
        let deleted = edits.deletedLayers.sorted { $0.key < $1.key }
        for (name, removal) in deleted {
            let drop = { KeybindingCatalog.deleteLayer(in: $0, named: name) }
            let reached = removal == .here ? [editing] : everyone
            snapshot.rewriteLayers(
                Dictionary(uniqueKeysWithValues: reached.map { ($0, drop) }),
                base: removal == .here ? nil : drop
            )
        }
        let edited = edits.layers.sorted { $0.key < $1.key }
        for (page, edit) in edited {
            guard let stored = edit.stored, stored != page else { continue }
            let table = snapshot.layerTable
            let rename = {
                KeybindingCatalog.renameLayer(in: $0, from: stored, to: page)
            }
            let users = everyone.filter {
                table.resolved(stored, for: $0) != nil
            }
            snapshot.rewriteLayers(
                Dictionary(uniqueKeysWithValues: users.map { ($0, rename) }),
                base: table.base[stored] != nil ? rename : nil
            )
        }
        for (page, edit) in edited {
            guard let members = edit.members,
                let content = config.layers.first(where: { $0.name == page })
            else { continue }
            setMembership(
                &snapshot,
                content,
                members,
                editing: editing
            )
        }
        return snapshot
    }

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
        reachEdits = edits
    }

    /// The name `name` is stored under: its edit's, else its own
    /// where a profile or the base holds it and the draft did not
    /// delete it. nil for a layer the draft created.
    func storedLayer(_ name: String) -> String? {
        if let edit = reachEdits.layers[name] { return edit.stored }
        guard reachEdits.deletedLayers[name] == nil,
            let table = ruleReachStored?.layerTable
        else { return nil }
        let held =
            table.base[name] != nil
            || table.profiles.contains { table.resolved(name, for: $0) != nil }
        return held ? name : nil
    }

    private func setMembership(
        _ snapshot: inout RuleReachSnapshot,
        _ content: KeyLayer,
        _ members: LayerMembers,
        editing: String
    ) {
        let name = content.name
        let table = snapshot.layerTable
        let order = config.layers.map(\.name)
        let add = {
            KeybindingCatalog.insertLayer(content, into: $0, order: order)
        }
        let drop = { KeybindingCatalog.deleteLayer(in: $0, named: name) }
        var transforms: [String: ([KeyLayer]) -> [KeyLayer]] = [:]
        for profile in table.profiles {
            let has = table.resolved(name, for: profile) != nil
            let wants =
                members.profiles.contains(profile) || profile == editing
            if wants && !has { transforms[profile] = add }
            if !wants && has { transforms[profile] = drop }
        }
        let inBase = table.base[name] != nil
        let base: (([KeyLayer]) -> [KeyLayer])? =
            members.shared == inBase ? nil : (members.shared ? add : drop)
        guard !transforms.isEmpty || base != nil else { return }
        snapshot.rewriteLayers(transforms, base: base)
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
