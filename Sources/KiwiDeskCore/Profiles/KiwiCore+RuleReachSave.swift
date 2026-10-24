import Foundation

extension KiwiCore {
    /// Writes an edited snapshot: each profile the change reached,
    /// then the shared base, then re-resolves the live rules so
    /// the loaded profile's page is what the screen does. A
    /// profile the change did not reach is not rewritten. Every
    /// reached file and the base are read and encoded before any
    /// write, so an unreadable one refuses the whole write rather
    /// than half of it.
    ///
    /// `keysLeftTo` names the stored profile whose shortcut override
    /// its own Save diffs from the page (`overwriteProfile`), which
    /// carries its layer structure too; its keys are skipped here.
    /// A write from `.outside` Settings — an AI app's keep or a
    /// shortcut verb (#1685) — leaves the rules as live holds them,
    /// registers the shortcuts, which have no live layer, from the
    /// files, and tells an open draft through `onRulesKept`.
    public func saveRuleReach(
        _ snapshot: RuleReachSnapshot,
        keysLeftTo page: String? = nil,
        origin: RuleWriteOrigin = .settings
    ) throws {
        guard snapshot.isEdited else { return }
        let app = snapshot.appRules
        let float = snapshot.floatRules
        let scroll = snapshot.scrollGestures
        let history = snapshot.spaceHistory
        let cycle = snapshot.modeCycle
        let wrap = snapshot.focusWrap
        let tile = snapshot.tileRules
        let automatic = snapshot.floatAutomatically
        var pending: [Profile] = []
        for name in app.profiles {
            let original = snapshot.storedFloatOverrides[name]
            let floatOverride = float.floatRuleOverride(
                for: name,
                original: original
            )
            let appTouched = !(app.touched[name] ?? []).isEmpty
            let keyTouched =
                name != page
                && (!(snapshot.keyLayers.touched[name] ?? []).isEmpty
                    || snapshot.storedKeyOverrides[name]
                        != snapshot.fileKeyOverrides[name])
            let scrollTouched = !(scroll.touched[name] ?? []).isEmpty
            let historyTouched = !(history.touched[name] ?? []).isEmpty
            let cycleTouched = !(cycle.touched[name] ?? []).isEmpty
            let wrapTouched = !(wrap.touched[name] ?? []).isEmpty
            let tileOriginal = snapshot.storedTileOverrides[name]
            let tileOverride = tile.floatRuleOverride(
                for: name,
                original: tileOriginal
            )
            let automaticTouched =
                !(automatic.touched[name] ?? []).isEmpty
            let lensMarks = snapshot.lensReach[name] ?? [:]
            let lensTouched =
                lensMarks != (snapshot.fileLensReach[name] ?? [:])
            guard
                appTouched || keyTouched || scrollTouched
                    || historyTouched || cycleTouched || wrapTouched
                    || floatOverride != original
                    || tileOverride != tileOriginal || automaticTouched
                    || lensTouched
            else { continue }
            var profile = try profiles.read(name: name)
            if appTouched {
                profile.appRules = app.appRuleOverride(for: name)
            }
            if keyTouched {
                profile.layers = snapshot.keyLayers.keyLayerOverride(
                    for: name,
                    original: snapshot.storedKeyOverrides[name],
                    newBase: snapshot.keyBase,
                    templates: snapshot.keyTemplates
                )
            }
            if scrollTouched {
                profile.scrollGesture = scroll.scrollGestureOverride(
                    for: name,
                    original: snapshot.storedScrollBase
                )
            }
            if historyTouched {
                profile.spaceHistory = history.spaceHistoryOverride(
                    for: name
                )
            }
            if cycleTouched {
                profile.modeCycle = cycle.modeCycleOverride(for: name)
            }
            if wrapTouched {
                profile.focusWrap = wrap.focusWrapOverride(for: name)
            }
            if automaticTouched {
                profile.floatAutomatically =
                    automatic.floatAutomaticallyOverride(for: name)
            }
            if lensTouched {
                profile.lensReach = lensMarks.isEmpty ? nil : lensMarks
            }
            profile.floatRules = floatOverride
            profile.tileRules = tileOverride
            pending.append(profile)
        }
        var sidecar: GuiConfig?
        let keysMoved =
            !snapshot.keyLayers.baseTouched.isEmpty
            || !RuleReachTable<String>.sameShortcuts(
                snapshot.keyBase,
                snapshot.fileKeyBase
            )
        if !app.baseTouched.isEmpty || !float.baseTouched.isEmpty
            || !scroll.baseTouched.isEmpty
            || !history.baseTouched.isEmpty
            || !cycle.baseTouched.isEmpty || keysMoved
            || !wrap.baseTouched.isEmpty
            || !tile.baseTouched.isEmpty || !automatic.baseTouched.isEmpty
        {
            guard var stored = guiConfigStore.load() else {
                throw SidecarError.unreadable
            }
            stored.appRules = app.appRuleBase(
                original: snapshot.storedAppBase
            )
            stored.floatRules = float.floatRuleBase(
                original: snapshot.storedFloatBase
            )
            stored.layers = snapshot.keyBase
            stored.scrollGesture = scroll.scrollGestureBase(
                original: snapshot.storedScrollBase
            )
            stored.spaceHistory = history.spaceHistoryBase
            stored.modeCycle = cycle.modeCycleBase
            stored.focusWrap = wrap.focusWrapBase
            stored.tileRules = tile.floatRuleBase(
                original: snapshot.storedTileBase
            )
            stored.floatAutomatically = automatic.floatAutomaticallyBase
            sidecar = stored
        }
        for profile in pending { try profiles.write(profile) }
        if let sidecar { try guiConfigStore.save(sidecar) }
        refreshConfigIssues()
        let keysChanged =
            keysMoved
            || snapshot.keyLayers.touched.values.contains { !$0.isEmpty }
            || snapshot.storedKeyOverrides != snapshot.fileKeyOverrides
        guard origin == .settings else {
            // Keys load only from files, so a written shortcut
            // registers now; the rules stay as live holds them.
            if keysChanged { reregisterStoredKeys() }
            onRulesKept()
            return
        }
        refreshStructuredOverrides(keys: keysChanged)
    }
}
