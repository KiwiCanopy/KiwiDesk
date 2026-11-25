import KiwiDeskCore

/// The Shortcuts page's gesture editors read and write the selected
/// layer's map (#3535): the one `nav.shortcutsLayer` the key parts
/// read, so a layer pick above the switcher retargets Mouse &
/// Trackpad too.
extension SettingsModel {
    /// The selected layer's sparse map in the draft.
    var gestureLayerMap: GestureMap {
        get { config.gesture[nav.shortcutsLayerSelection] }
        set { config.gesture[nav.shortcutsLayerSelection] = newValue }
    }

    /// What the selected layer's map lies over.
    var gestureScope: GestureSeedScope {
        GestureSeedScope(
            shortcutBase: config.shortcutBase,
            layer: nav.shortcutsLayerSelection
        )
    }
}

extension SettingsModel {
    /// `key`'s spelling in the gesture reach table, on the selected
    /// layer (`LayerGestureKey`).
    func gestureReachKey(_ key: GestureKey) -> String {
        LayerGestureKey(nav.shortcutsLayerSelection, key).spelling
    }
}

extension SettingsModel {
    /// What the default layer's map lies over, whatever is selected.
    var defaultGestureScope: GestureSeedScope {
        .defaultLayer(on: config.shortcutBase)
    }
}

extension SettingsModel {
    /// The page's gesture rows the encode compares against `table`:
    /// the draft's, laid over the seeds, and as stored for a layer
    /// the page does not hold, which is no row of the page's — a
    /// layer deleted here leaves the shared base's rows standing
    /// (#3535).
    func gestureEncodeCurrent(
        _ table: RuleReachTable<GestureAction>,
        _ editing: String
    ) -> [String: GestureAction] {
        var current = RuleReachTable<GestureAction>.gestureSeedsUnder(
            config.gesture,
            shortcutBase: config.shortcutBase
        )
        let page = Set(config.layers.map(\.name))
            .union([KeyLayer.defaultName])
        for (spelling, action) in table.resolved(for: editing) {
            guard let key = LayerGestureKey(spelling: spelling),
                !page.contains(key.layer)
            else { continue }
            current[spelling] = action
        }
        return current
    }
}
