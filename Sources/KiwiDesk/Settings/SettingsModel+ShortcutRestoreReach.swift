import KiwiDeskCore

/// Shortcuts' Restore Defaults as the key reach table sees it
/// (#3248): the default layer's rows keyed by `layer␟lua`, so the
/// Save writes the restore as far as the dialog's answer.
extension SettingsModel {
    /// The default layer's seeds and its page values before and
    /// after a restore; nil without a default layer.
    var shortcutRestore: RestoreSeeds<String>? {
        guard
            let layer = config.layers.first(where: {
                $0.name == KeyLayer.defaultName
            })
        else { return nil }
        var seeded = layer
        seeded.bindings = shippedDefaults(on: config.shortcutBase)
        var restored = layer
        restored.bindings = restoredDefaultRows(layer.bindings)
        return RestoreSeeds(
            seeds: RuleReachTable<String>.combos([seeded]),
            before: RuleReachTable<String>.combos([layer]),
            after: RuleReachTable<String>.combos([restored])
        )
    }

    /// The other profiles that changed the default layer's seeded
    /// rows — whose answer a restore must ask for (#3248 ▸
    /// Amendment). Empty without a checklist.
    var shortcutsRestoreChangedElsewhere: [String] {
        guard let reach = encodedReach, let editing = reachProfile,
            let restore = shortcutRestore
        else { return [] }
        return restore.changedElsewhere(
            in: reach.keyLayers,
            editing: editing
        )
    }
}
