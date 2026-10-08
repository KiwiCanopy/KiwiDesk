import KiwiDeskCore

/// Every layer the page gains is recorded as a membership the layer
/// pass places (#2022) — Add and Import alike — so the page never
/// decides on its own which layers exist where.
extension SettingsModel {
    /// Adds `name` to the page and says whether it did. A name the
    /// shared base holds puts this profile back in that layer; a
    /// name only another profile's own layer holds is refused.
    @discardableResult
    func addLayer(_ name: String) -> Bool {
        guard !name.isEmpty,
            !config.layers.contains(where: { $0.name == name }),
            layerAddClash(name) == nil
        else { return false }
        if let shared = layeredReach?.storedKeyBase.first(where: {
            $0.name == name
        }) {
            rejoin(shared)
            return true
        }
        // Every layer carries the app-chrome rows (#602, #1381).
        config.layers.append(
            KeyLayer(name: name, bindings: DefaultKeybindings.appChromeRows())
        )
        recordCreated([name])
        return true
    }

    /// Whether adding `name` puts this profile back in a shared
    /// layer it leaves out, rather than making a new one.
    func layerAddRejoins(_ name: String) -> Bool {
        !name.isEmpty
            && !config.layers.contains { $0.name == name }
            && layeredReach?.storedKeyBase.contains { $0.name == name } == true
    }

    /// The profile whose own layer already takes `name`: a new layer
    /// by that name would merge into it. A shared layer is rejoined
    /// instead (`addLayer`), so it never clashes.
    func layerAddClash(_ name: String) -> String? {
        guard let editing = reachProfile,
            let table = layeredReach?.layerTable,
            table.base[name] == nil
        else { return nil }
        return profileMenuOrder.filter(table.profiles.contains)
            .first { $0 != editing && table.resolved(name, for: $0) != nil }
    }

    /// Imports live Lua shortcuts into the page (`KeybindingMerge`,
    /// #4): a layer the import brings is recorded like an added one.
    func importShortcuts(_ recovered: [KeyLayer]) {
        let before = Set(config.layers.map(\.name))
        var updated = config
        KeybindingMerge.merge(recovered: recovered, into: &updated)
        KeybindingImportClassifier.classify(
            &updated,
            recoverResizeStep: true
        )
        // After the classifier, which is what makes a row an
        // action (#1807).
        droppedChords = NavigationChords.deduplicate(&updated)
        config = updated
        recordCreated(
            updated.layers.map(\.name).filter { !before.contains($0) }
        )
    }

    /// Records each new page layer where a new row starts
    /// (`RuleReachDraft.defaultReach`).
    private func recordCreated(_ names: [String]) {
        guard !names.isEmpty, let editing = reachProfile,
            let table = layeredReach?.layerTable
        else { return }
        var edits = reachEdits
        for name in names {
            let members: LayerMembers
            switch RuleReachDraft.defaultReach(
                of: name,
                in: table,
                editing: editing,
                isLoaded: reachIsLoaded
            ) {
            case .shared:
                members = LayerMembers(
                    shared: true,
                    profiles: Set(table.profiles)
                )
            case .listed(let profiles):
                members = LayerMembers(
                    shared: false,
                    profiles: profiles.union([editing])
                )
            }
            edits.layers[name] = LayerEdit(stored: nil, members: members)
        }
        reachEdits = edits
    }

    /// Puts the edited profile back in the shared layer `shared` by
    /// ticking it into the layer's membership — over a draft's own
    /// Delete from here too, whose switch rows stay gone.
    private func rejoin(_ shared: KeyLayer) {
        let name = shared.name
        let holders = layerReach(name)?.users ?? []
        config.layers = KeybindingCatalog.insertLayer(
            shared,
            into: config.layers,
            order: layeredReach?.storedKeyBase.map(\.name) ?? []
        )
        guard let editing = reachProfile else { return }
        var edits = reachEdits
        edits.layers[name] = LayerEdit(
            stored: name,
            members: LayerMembers(
                shared: true,
                profiles: holders.union([editing])
            )
        )
        reachEdits = edits
    }
}
