import KiwiDeskCore

/// Deleting and renaming a layer across the profiles that have it
/// (#2022): delete asks how far, rename reaches every profile the
/// "Applies to" reading lists and never forks.
extension SettingsModel {
    /// Deletes the page's layer `name`, and every row switching to
    /// it, from this profile alone or from every profile.
    func deleteLayer(_ name: String, _ removal: RuleRemoval) {
        guard name != KeyLayer.defaultName else { return }
        let stored = storedLayer(name)
        var edits = reachEdits
        edits.layers[name] = nil
        if let stored { edits.deletedLayers[stored] = removal }
        LayerRowPicks.deleted(&edits, layer: name)
        config.layers = KeybindingCatalog.deleteLayer(
            in: config.layers,
            named: name
        )
        reachEdits = edits
    }

    /// Adds a layer to the page, carrying the app-chrome rows (#602,
    /// #1381), and records where it starts — where a new row does
    /// (`RuleReachDraft.defaultReach`) — so the layer pass, the one
    /// decider of which layers exist where, places it (#2022).
    func addLayer(_ name: String) {
        config.layers.append(
            KeyLayer(name: name, bindings: DefaultKeybindings.appChromeRows())
        )
        guard let editing = reachProfile,
            let table = layeredReach?.layerTable
        else { return }
        let members: LayerMembers
        switch RuleReachDraft.defaultReach(
            of: name,
            in: table,
            editing: editing,
            isLoaded: reachIsLoaded
        ) {
        case .shared:
            members = LayerMembers(shared: true, profiles: Set(table.profiles))
        case .listed(let profiles):
            members = LayerMembers(
                shared: false,
                profiles: profiles.union([editing])
            )
        }
        var edits = reachEdits
        edits.layers[name] = LayerEdit(stored: nil, members: members)
        reachEdits = edits
    }

    /// The profile that still holds a layer named `name`, which a
    /// new layer may not take: it would merge into that one.
    func layerAddClash(_ name: String) -> String? {
        guard let editing = reachProfile,
            let table = layeredReach?.layerTable
        else { return nil }
        let holder = profileMenuOrder.filter(table.profiles.contains)
            .first { $0 != editing && table.resolved(name, for: $0) != nil }
        if let holder { return holder }
        return table.base[name] != nil ? editing : nil
    }

    /// Renames the page's layer, and its switch rows, in every
    /// profile that has it. A row's own pick follows the new name.
    func renameLayer(_ old: String, to new: String) {
        guard old != KeyLayer.defaultName, old != new else { return }
        var edits = reachEdits
        let edit =
            edits.layers.removeValue(forKey: old)
            ?? LayerEdit(stored: storedLayer(old))
        if !edit.isInert(at: new) { edits.layers[new] = edit }
        LayerRowPicks.renamed(&edits, from: old, to: new)
        config.layers = KeybindingCatalog.renameLayer(
            in: config.layers,
            from: old,
            to: new
        )
        reachEdits = edits
    }

    /// The first profile the rename of `old` reaches that already
    /// has a layer named `new` — the page's own included, by its
    /// profile's name where it has one.
    func layerRenameClash(_ old: String, _ new: String) -> String? {
        guard new != old else { return nil }
        let editing = reachProfile ?? editingProfile ?? activeProfile
        if let editing, config.layers.contains(where: { $0.name == new }) {
            return editing
        }
        guard let editing, let row = layerReach(old),
            let reach = layeredReach
        else { return nil }
        // A profile left out of a shared layer is reached too: its
        // mark follows the rename, which would merge the layer into
        // a layer of its own by that name.
        let shared = reach.layerTable.base[old] != nil
        return row.profiles.first { profile in
            profile != editing && (shared || row.users.contains(profile))
                && reach.storedKeyLayers(for: profile).contains {
                    $0.name == new
                }
        }
    }

    /// How many shortcuts a delete of `name` takes from THIS page:
    /// its own rows and every row here that switches to it. Another
    /// profile's copy is named by the message's second sentence,
    /// never counted, since its rows may differ.
    func layerDeleteCount(_ name: String) -> Int {
        let switchTo = KeybindingCatalog.switchLayerCommand(name).lua
        let own = config.layers.first { $0.name == name }?.bindings.count
        let switches = config.layers.reduce(0) { total, layer in
            total + layer.bindings.filter { $0.lua == switchTo }.count
        }
        return (own ?? 0) + switches
    }

    /// Whether a delete of `name` asks first: it does unless the
    /// layer holds only the app-chrome rows, nothing switches to it
    /// and no other profile has it.
    func layerDeleteAsks(_ name: String) -> Bool {
        let chrome = Set(DefaultKeybindings.appChromeRows().map(\.lua))
        let rows = config.layers.first { $0.name == name }?.bindings ?? []
        let switchTo = KeybindingCatalog.switchLayerCommand(name).lua
        let switches = config.layers.contains { layer in
            layer.bindings.contains { $0.lua == switchTo }
        }
        let others = layerReach(name).map { $0.users.count > 1 } ?? false
        return others || switches || rows.contains { !chrome.contains($0.lua) }
    }
}
