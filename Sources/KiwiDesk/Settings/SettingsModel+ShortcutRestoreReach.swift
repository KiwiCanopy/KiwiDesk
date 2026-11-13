import KiwiDeskCore

/// Shortcuts' Restore Defaults as the key reach table sees it
/// (#3248): the default layer's rows keyed by `layer␟lua`, so the
/// Save writes the restore as far as the dialog's answer.
extension SettingsModel {
    /// The default layer's shared seeds and its page values before
    /// and after a restore; nil without a default layer. A seed row
    /// a profile's own Spaces or resize step spell otherwise — a
    /// digit row, a resize row — is that profile's, so only the rows
    /// every profile's seed agrees on are shared or asked about.
    var shortcutRestore: RestoreSeeds<String>? {
        guard
            let layer = config.layers.first(where: {
                $0.name == KeyLayer.defaultName
            })
        else { return nil }
        var restored = layer
        restored.bindings = restoredDefaultRows(layer.bindings)
        return RestoreSeeds(
            seeds: sharedShortcutSeeds(layer),
            before: RuleReachTable<String>.combos([layer]),
            after: RuleReachTable<String>.combos([restored])
        )
    }

    /// The other profiles that changed a shared seed row of the
    /// default layer — whose answer a restore must ask for (#3248 ▸
    /// Amendment). Empty without a checklist.
    var shortcutsRestoreChangedElsewhere: [String] {
        guard let reach = encodedReach, let editing = reachProfile,
            let restore = shortcutRestore
        else { return [] }
        return reach.keyLayers.profilesAway(
            from: restore.seeds,
            editing: editing
        )
    }

    /// The page's seed, keyed, less every row another profile's own
    /// seed spells differently; a profile whose file will not read
    /// narrows nothing, its write being refused at the Save.
    private func sharedShortcutSeeds(_ layer: KeyLayer) -> [String: String] {
        var page = layer
        page.bindings = shippedDefaults(on: config.shortcutBase)
        var shared = RuleReachTable<String>.combos([page])
        let others = Set(layeredReach?.keyLayers.profiles ?? [])
            .subtracting([reachProfile].compactMap { $0 })
        // One pass over the files, the read the reach snapshot takes.
        for profile in core.profiles.allProfiles()
        where others.contains(profile.name) {
            var own = layer
            own.bindings = shippedDefaults(
                on: config.shortcutBase,
                spaces: profile.spaces,
                resizeStep: profile.settings.resizeStep
            )
            let theirs = RuleReachTable<String>.combos([own])
            shared = shared.filter { theirs[$0.key] == $0.value }
        }
        return shared
    }
}
