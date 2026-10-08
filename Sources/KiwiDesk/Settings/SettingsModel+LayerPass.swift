import KiwiDeskCore

/// The one layer pass (#2022): the draft's deletes, renames and
/// memberships laid over the stored shortcut files, AHEAD of the
/// row encode (`encodedReach`), derived once per draft change.
extension SettingsModel {
    /// The stored rules with the draft's layer edits laid over the
    /// shortcut files — what the key table encodes row edits
    /// against. nil without a checklist.
    var layeredReach: RuleReachSnapshot? {
        let key = LayeredReachCache.Key(
            edits: reachEdits,
            page: config.layers,
            profile: reachProfile
        )
        if let cache = layeredCache, cache.key == key { return cache.value }
        let value = layeredReach(reachEdits)
        layeredCache = LayeredReachCache(key: key, value: value)
        return value
    }

    /// The pass over `edits`, uncached — for a reading taken
    /// without one of the draft's picks.
    func layeredReach(_ edits: RuleReachEdits) -> RuleReachSnapshot? {
        guard let stored = ruleReachStored, let editing = reachProfile
        else { return ruleReachStored }
        guard !edits.layers.isEmpty || !edits.deletedLayers.isEmpty else {
            return stored
        }
        var snapshot = stored
        do {
            try deletePass(&snapshot, edits, editing: editing)
            try renamePass(&snapshot, edits)
            for (page, edit) in edits.layers.sorted(by: { $0.key < $1.key }) {
                guard let members = edit.members,
                    let content = config.layers.first(where: {
                        $0.name == page
                    })
                else { continue }
                try membershipPass(&snapshot, content, members, editing)
            }
        } catch {
            assertionFailure("layer pass after a row encode: \(error)")
            return stored
        }
        return snapshot
    }

    /// A delete reaches the edited profile, or every file holding
    /// the layer or a row switching to it, and the base.
    private func deletePass(
        _ snapshot: inout RuleReachSnapshot,
        _ edits: RuleReachEdits,
        editing: String
    ) throws {
        for (name, removal) in edits.deletedLayers.sorted(by: {
            $0.key < $1.key
        }) {
            let drop = { KeybindingCatalog.deleteLayer(in: $0, named: name) }
            let switchTo = KeybindingCatalog.switchLayerCommand(name).lua
            let reached =
                removal == .here
                ? [editing]
                : snapshot.keyLayers.profiles.filter { profile in
                    snapshot.storedKeyLayers(for: profile).contains {
                        $0.name == name
                            || $0.bindings.contains { $0.lua == switchTo }
                    }
                }
            try snapshot.rewriteLayers(
                Dictionary(uniqueKeysWithValues: reached.map { ($0, drop) }),
                base: removal == .here ? nil : drop
            )
        }
    }

    /// Every rename as ONE stored → page name map, applied at once,
    /// so a chain or a swap cannot merge two layers.
    private func renamePass(
        _ snapshot: inout RuleReachSnapshot,
        _ edits: RuleReachEdits
    ) throws {
        var map: [String: String] = [:]
        for (page, edit) in edits.layers {
            if let stored = edit.stored, stored != page { map[stored] = page }
        }
        guard !map.isEmpty else { return }
        let rename = { Self.renaming($0, map) }
        let holders = snapshot.keyLayers.profiles.filter { profile in
            snapshot.storedKeyLayers(for: profile).contains {
                map[$0.name] != nil
            }
        }
        let inBase = snapshot.storedKeyBase.contains { map[$0.name] != nil }
        try snapshot.rewriteLayers(
            Dictionary(uniqueKeysWithValues: holders.map { ($0, rename) }),
            base: inBase ? rename : nil
        )
    }

    /// `layers` with each layer it holds renamed by `map`, through a
    /// placeholder per name so the renames land simultaneously.
    static func renaming(
        _ layers: [KeyLayer],
        _ map: [String: String]
    ) -> [KeyLayer] {
        let held = map.filter { from, _ in
            layers.contains { $0.name == from }
        }.sorted { $0.key < $1.key }
        var result = layers
        for (at, rename) in held.enumerated() {
            result = KeybindingCatalog.renameLayer(
                in: result,
                from: rename.key,
                to: "\u{1F}\(at)"
            )
        }
        for (at, rename) in held.enumerated() {
            result = KeybindingCatalog.renameLayer(
                in: result,
                from: "\u{1F}\(at)",
                to: rename.value
            )
        }
        return result
    }

    private func membershipPass(
        _ snapshot: inout RuleReachSnapshot,
        _ content: KeyLayer,
        _ members: LayerMembers,
        _ editing: String
    ) throws {
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
        try snapshot.rewriteLayers(transforms, base: base)
    }
}

/// The last layer pass and the draft it read.
struct LayeredReachCache {
    struct Key: Equatable {
        let edits: RuleReachEdits
        let page: [KeyLayer]
        let profile: String?
    }

    let key: Key
    let value: RuleReachSnapshot?
}
