import KiwiDeskCore

/// What a layer the page would gain becomes (#2022).
enum LayerAdmission: Equatable {
    /// A layer no file holds: it starts where a new row does.
    case new
    /// A shared layer this profile leaves out: it rejoins it.
    case rejoin
    /// Another profile's own layer by that name: it would merge.
    case clash(String)
    /// A shared layer this STORED page leaves out: it is joined on
    /// the loaded profile's page (owner ruling, #2022).
    case sharedElsewhere
}

/// An imported layer that took a free name, and why (#2022).
struct LayerImportRename: Equatable {
    let from: String
    let to: String
    let reason: LayerAdmission
}

/// Every layer the page gains goes through ONE decider,
/// `layerAdmission`, and is recorded as a membership the layer pass
/// places (#2022) — Add and Import alike — so the page never
/// decides on its own which layers exist where.
extension SettingsModel {
    /// What adding `name` would do; nil for an empty name or one
    /// the page already has.
    func layerAdmission(_ name: String) -> LayerAdmission? {
        guard !name.isEmpty,
            !config.layers.contains(where: { $0.name == name })
        else { return nil }
        if let holder = layerAddClash(name) { return .clash(holder) }
        let shared = layeredReach?.storedKeyBase.contains {
            $0.name == name
        }
        guard shared == true else { return .new }
        return reachIsLoaded ? .rejoin : .sharedElsewhere
    }

    /// Why renaming the page's layer `old` to `new` is refused, in
    /// words; nil when it may. A rename takes only a name the
    /// decider calls `.new` — never a shared layer's, which Add
    /// joins — and never one a profile the rename reaches holds.
    func layerRenameRefusal(_ old: String, _ new: String) -> String? {
        guard new != old else { return nil }
        if let holder = layerRenameClash(old, new) {
            return LayerReachWords.clash(holder, new)
        }
        switch layerAdmission(new) {
        case .new?, nil: return nil
        case .clash(let holder)?: return LayerReachWords.clash(holder, new)
        case .rejoin?: return LayerReachWords.renameOntoShared(new)
        case .sharedElsewhere?: return LayerReachWords.joinOnLoadedPage
        }
    }

    /// Whether Add may take `name`.
    func canAddLayer(_ name: String) -> Bool {
        switch layerAdmission(name) {
        case .new?, .rejoin?: true
        case .clash?, .sharedElsewhere?, nil: false
        }
    }

    /// Whether adding `name` puts this profile back in a shared
    /// layer it leaves out, rather than making a new one.
    func layerAddRejoins(_ name: String) -> Bool {
        layerAdmission(name) == .rejoin
    }

    /// Adds `name` to the page and says whether it did.
    @discardableResult
    func addLayer(_ name: String) -> Bool {
        switch layerAdmission(name) {
        case .rejoin?:
            guard
                let shared = layeredReach?.storedKeyBase.first(where: {
                    $0.name == name
                })
            else { return false }
            config.layers = KeybindingCatalog.insertLayer(
                shared,
                into: config.layers,
                order: layeredReach?.storedKeyBase.map(\.name) ?? []
            )
            recordRejoined([name])
            return true
        case .new?:
            // Every layer carries the app-chrome rows (#602, #1381).
            config.layers.append(
                KeyLayer(
                    name: name,
                    bindings: DefaultKeybindings.appChromeRows()
                )
            )
            recordCreated([name])
            return true
        case .clash?, .sharedElsewhere?, nil:
            return false
        }
    }

    /// The profile whose own layer already takes `name`: a new layer
    /// by that name would merge into it. A shared layer is rejoined
    /// instead, so it never clashes.
    func layerAddClash(_ name: String) -> String? {
        guard let editing = reachProfile,
            let table = layeredReach?.layerTable,
            table.base[name] == nil
        else { return nil }
        return profileMenuOrder.filter(table.profiles.contains)
            .first { $0 != editing && table.resolved(name, for: $0) != nil }
    }

    /// Imports live Lua shortcuts into the page (`KeybindingMerge`,
    /// #4). Each layer it brings takes `layerAdmission` as Add does;
    /// one whose name another profile's own layer holds is imported
    /// under the first free numbered name rather than merged.
    func importShortcuts(_ recovered: [KeyLayer]) {
        var incoming = recovered
        var taken = Set(config.layers.map(\.name))
            .union(recovered.map(\.name))
        var created: [String] = []
        var rejoined: [String] = []
        var renames: [LayerImportRename] = []
        for layer in recovered {
            switch layerAdmission(layer.name) {
            case .new?: created.append(layer.name)
            case .rejoin?: rejoined.append(layer.name)
            case .clash?, .sharedElsewhere?:
                // Imported as its own layer under a free name, and
                // said so (`importRenames`).
                let free = freeLayerName(layer.name, taken: taken)
                taken.insert(free)
                incoming = KeybindingCatalog.renameLayer(
                    in: incoming,
                    from: layer.name,
                    to: free
                )
                created.append(free)
                renames.append(
                    LayerImportRename(
                        from: layer.name,
                        to: free,
                        reason: layerAdmission(layer.name) ?? .new
                    )
                )
            case nil: break
            }
        }
        var updated = config
        KeybindingMerge.merge(recovered: incoming, into: &updated)
        KeybindingImportClassifier.classify(
            &updated,
            recoverResizeStep: true
        )
        // After the classifier, which is what makes a row an
        // action (#1807).
        droppedChords = NavigationChords.deduplicate(&updated)
        importRenames = renames
        config = updated
        recordCreated(created)
        recordRejoined(rejoined)
    }

    /// `name 2`, `name 3`, … — the first no layer holds.
    private func freeLayerName(_ name: String, taken: Set<String>)
        -> String
    {
        var number = 2
        while true {
            let candidate = "\(name) \(number)"
            if !taken.contains(candidate),
                layerAdmission(candidate) == .new
            {
                return candidate
            }
            number += 1
        }
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

    /// Ticks the edited profile back into each shared layer — over a
    /// draft's own Delete from here too, whose switch rows stay gone.
    /// Every other holder keeps the layer.
    private func recordRejoined(_ names: [String]) {
        guard !names.isEmpty, let editing = reachProfile else { return }
        var edits = reachEdits
        for name in names {
            let holders = layerReach(name)?.users ?? []
            edits.layers[name] = LayerEdit(
                stored: name,
                members: LayerMembers(
                    shared: true,
                    profiles: holders.union([editing])
                )
            )
        }
        reachEdits = edits
    }
}
