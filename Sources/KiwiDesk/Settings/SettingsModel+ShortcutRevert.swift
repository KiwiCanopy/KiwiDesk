import KiwiDeskCore

/// A shortcut row's ↺ (#2412): one binding with the bindings its
/// chords moved between, or a whole layer, or one profile's
/// membership — against the saved layers on the draft's shortcut
/// base (#2460), the rows' own baseline.
extension SettingsModel {
    /// The saved layers on the draft's shortcut base.
    var revertBaseline: [KeyLayer] {
        cleanConfig.onShortcutBase(config.shortcutBase).layers
    }

    /// The name the baseline holds the page's layer `page` under.
    func savedLayerName(_ page: String) -> String {
        storedLayer(page) ?? page
    }

    /// The binding a binding row or a shortcut's reach row names.
    func revertedBinding(
        _ row: SettingsDiffRow
    ) -> (layer: String, lua: String)? {
        switch row.revert {
        case .binding(let layer, let lua):
            return (layer, lua)
        case .ruleReach(let key) where row.key == .shortcuts(.layers):
            let parts = RuleReachTable<String>.keyParts(key)
            return (parts.layer, parts.lua)
        default:
            return nil
        }
    }

    /// The actions a binding's ↺ takes back, its own first.
    func revertActions(layer: String, lua: String) -> [String] {
        BindingRevertSet.walk(
            layer: layer,
            saved: savedLayerName(layer),
            lua: lua,
            draft: config.layers,
            baseline: revertBaseline
        )
    }

    /// The names of the OTHER bindings `row`'s ↺ takes back, for
    /// its words — read from the walk the revert runs.
    func revertCompanions(_ row: SettingsDiffRow) -> [String] {
        guard let (layer, lua) = revertedBinding(row) else { return [] }
        let saved = savedLayerName(layer)
        let rows =
            (config.layers.first { $0.name == layer }?.bindings ?? [])
            + (revertBaseline.first { $0.name == saved }?.bindings ?? [])
        return revertActions(layer: layer, lua: lua).dropFirst()
            .compactMap { action in
                rows.first { $0.lua == action }.map {
                    KeybindingCatalog.localizedName(of: $0, config: config)
                }
            }
    }

    /// One binding back as saved, with its walk's set and their
    /// reach picks.
    func revertBinding(layer: String, lua: String) {
        let actions = revertActions(layer: layer, lua: lua)
        var edits = reachEdits
        Self.dropKeyPicks(
            actions.map {
                RuleReachTable<String>.keyID(layer: layer, lua: $0)
            },
            in: &edits
        )
        config.layers = BindingRevertSet.restore(
            actions,
            layer: layer,
            saved: savedLayerName(layer),
            draft: config.layers,
            baseline: revertBaseline
        )
        reachEdits = edits
    }

    /// Both sides of the layer edit a row names: a row naming one
    /// side of a rename finds the other.
    func layerRevertSides(
        stored: String?,
        page: String?
    ) -> (stored: String?, page: String?) {
        let page =
            page
            ?? reachEdits.layers.first { $0.value.stored == stored }?.key
        return (stored ?? page.flatMap(storedLayer), page)
    }

    /// Whether another draft layer now holds the saved name, so the
    /// layer cannot come back under it; its ↺ is not drawn.
    func layerRevertBlocked(stored: String?, page: String?) -> Bool {
        let sides = layerRevertSides(stored: stored, page: page)
        guard let stored = sides.stored, stored != sides.page else {
            return false
        }
        return config.layers.contains { $0.name == stored }
    }

    /// The layer a row names back as saved: the page's copy and
    /// every row switching to it go through the delete's own
    /// staging, the saved layer and its switch rows return, with the
    /// bindings their chords moved between.
    func revertLayer(stored: String?, page: String?) {
        let sides = layerRevertSides(stored: stored, page: page)
        let baseline = revertBaseline
        var edits = reachEdits
        if let page = sides.page { dropDraftLayer(page, in: &edits) }
        if let stored = sides.stored {
            edits.deletedLayers[stored] = nil
            if let saved = baseline.first(where: { $0.name == stored }) {
                config.layers = KeybindingCatalog.insertLayer(
                    saved,
                    into: config.layers,
                    order: baseline.map(\.name)
                )
                let renamed = edits.layers
                let back = BindingRevertSet.restoreEverywhere(
                    KeybindingCatalog.switchLayerCommand(stored).lua,
                    draft: config.layers,
                    baseline: baseline,
                    saved: { renamed[$0]?.stored ?? $0 }
                )
                config.layers = back.layers
                Self.dropKeyPicks(back.keys, in: &edits)
            }
        }
        reachEdits = edits
    }

    /// Drops the reach picks of `keys`, as a binding's revert takes
    /// its picks with it.
    static func dropKeyPicks(_ keys: [String], in edits: inout RuleReachEdits)
    {
        for key in keys {
            edits.reach[.key]?[key] = nil
            edits.removal[.key]?[key] = nil
        }
    }

    /// One profile's membership of `page` — or the shared base's,
    /// for a nil `profile` — back to what the layer has without the
    /// draft's picks.
    func revertLayerMembers(page: String, profile: String?) {
        var bare = reachEdits
        bare.layers[page]?.members = nil
        guard let before = layerReach(page, edits: bare) else { return }
        if let profile {
            setLayerProfile(page, profile, before.users.contains(profile))
        } else {
            setLayerAllProfiles(page, before.shared)
        }
    }

    /// A binding row whose action is a layer's switch or a lens's
    /// toggle, of a layer or lens the draft renamed, deleted or
    /// created, reverts with that layer or lens, never alone — a
    /// lone revert would bring back a row for a name the page no
    /// longer has.
    func ownedRevert(_ revert: SettingsRowRevert) -> SettingsRowRevert {
        guard case .binding(_, let lua) = revert else { return revert }
        if let layer = KeybindingCatalog.switchTarget(of: lua),
            let owned = layerEditRevert(layer)
        {
            return owned
        }
        if let lens = KeybindingCatalog.lensTarget(of: lua),
            let owned = lensEditRevert(lens)
        {
            return owned
        }
        return revert
    }

    /// A draft layer holding the name wins over a deleted one of
    /// that name, whose ↺ a reused name blocks.
    private func layerEditRevert(_ name: String) -> SettingsRowRevert? {
        if let edit = reachEdits.layers[name], edit.stored != name {
            return .layer(stored: edit.stored, page: name)
        }
        if reachEdits.deletedLayers[name] != nil {
            return .layer(stored: name, page: nil)
        }
        if reachEdits.layers.contains(where: {
            $0.value.stored == name && $0.key != name
        }) {
            return .layer(stored: name, page: nil)
        }
        return nil
    }
}

extension GuiConfig {
    /// This config with its rows moved onto `base` as the switch
    /// moves them (#2460) — the baseline the shortcut rows and their
    /// ↺ are read against.
    func onShortcutBase(_ base: ShortcutBase) -> GuiConfig {
        guard shortcutBase != base else { return self }
        var config = self
        ShortcutBaseSwitch.apply(base, to: &config)
        return config
    }
}
