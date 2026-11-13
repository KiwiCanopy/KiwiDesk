import KiwiDeskCore

/// Which profiles a gesture binding reaches (#3225). A re-keyed row
/// carries its reach through `carryPick`, as a sequence does.
extension SettingsModel {
    /// The checklist of a gesture row, keyed by
    /// `GestureKey.spelling`; nil without a checklist.
    func gestureReach(_ key: String) -> RuleReachReading? {
        guard let reach = encodedReach else { return nil }
        return reading(
            reach.gestures,
            key,
            reach.unreadable,
            picked: reachEdits.reach[.gesture]?[key]
        ) { GestureListWords.value($0) }
    }

    /// A row whose new gesture refuses its action loses it: the old
    /// key's pick goes, and its removal is `.here` where another
    /// profile holds the row, `.everywhere` otherwise.
    func dropGesturePick(_ key: String, shared: Bool) {
        reachEdits.reach[.gesture]?[key] = nil
        recordRemoval(.gesture, key, shared ? .here : .everywhere)
    }
}

/// A gesture card's Restore Defaults (#3248 ▸ Ruling), keyed as the
/// gesture reach table keys a binding.
extension SettingsModel {
    /// `device`'s seeds and the page's map before and after the
    /// card restores them.
    func gestureRestore(
        on device: GestureInput.Device
    ) -> RestoreSeeds<GestureAction> {
        var restored = config.gesture
        GestureListEdits.restoreDefaults(on: device, in: &restored)
        var seeds: [String: GestureAction] = [:]
        for (key, action) in GestureSeeds.seeds
        where key.input.device == device {
            seeds[key.spelling] = action
        }
        return RestoreSeeds(
            seeds: seeds,
            before: RuleReachTable<GestureAction>.gestureSeedsUnder(
                config.gesture
            ),
            after: RuleReachTable<GestureAction>.gestureSeedsUnder(
                restored
            )
        )
    }

    /// The other profiles that changed one of `device`'s seeded
    /// gestures; empty without a checklist.
    func gestureRestoreChangedElsewhere(
        on device: GestureInput.Device
    ) -> [String] {
        guard let reach = encodedReach, let editing = reachProfile
        else { return [] }
        return gestureRestore(on: device).changedElsewhere(
            in: reach.gestures,
            editing: editing
        )
    }

    /// Restores `device`'s seeded gestures as far as `reach` says;
    /// the rows the user added stay.
    func restoreGestureDefaults(
        on device: GestureInput.Device,
        reach: RestoreReach
    ) {
        let restore = gestureRestore(on: device)
        let profiles = encodedReach?.gestures.profiles ?? []
        GestureListEdits.restoreDefaults(on: device, in: &config.gesture)
        stageRestore(.gesture, restore, profiles: profiles, reach: reach)
    }
}
