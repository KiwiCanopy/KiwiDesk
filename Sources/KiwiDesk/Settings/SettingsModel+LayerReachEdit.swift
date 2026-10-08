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
        config.layers = KeybindingCatalog.deleteLayer(
            in: config.layers,
            named: name
        )
        reachEdits = edits
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
        edits.reach[.key] = rekeyed(edits.reach[.key], old, new)
        edits.removal[.key] = rekeyed(edits.removal[.key], old, new)
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
        return row.profiles.first { profile in
            profile != editing && row.users.contains(profile)
                && reach.storedKeyLayers(for: profile).contains {
                    $0.name == new
                }
        }
    }

    /// How many shortcuts a delete of `name` takes: its own rows
    /// and every row on the page that switches to it.
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

    private func rekeyed<V>(
        _ map: [String: V]?,
        _ old: String,
        _ new: String
    ) -> [String: V]? {
        guard let map else { return nil }
        let oldSwitch = KeybindingCatalog.switchLayerCommand(old).lua
        let newSwitch = KeybindingCatalog.switchLayerCommand(new).lua
        var result: [String: V] = [:]
        for (key, value) in map {
            var (layer, lua) = RuleReachTable<String>.keyParts(key)
            if layer == old { layer = new }
            if lua == oldSwitch { lua = newSwitch }
            result[RuleReachTable<String>.keyID(layer: layer, lua: lua)] =
                value
        }
        return result
    }
}
