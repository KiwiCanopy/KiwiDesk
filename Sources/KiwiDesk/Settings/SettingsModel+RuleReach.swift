import KiwiDeskCore

/// Which profiles an App Rule reaches (#1393): the stored table,
/// the draft's choices over it, and the writes a Save owes.
extension SettingsModel {
    /// The profile whose page the checklist is read from — the
    /// edited one, or the loaded one on the live target. nil hides
    /// the column: no profile to name, or no GUI-owned base.
    var reachProfile: String? { reachPage }

    /// Whether the page is the loaded profile's, which decides a
    /// new rule's starting reach.
    var reachIsLoaded: Bool { editingProfile == nil }

    /// The profile the checklist marks "loaded": on the live
    /// target the page's own, pinned with it; on a stored page the
    /// one on screen.
    var reachLoaded: String? { reachIsLoaded ? reachPage : activeProfile }

    /// The stored tables with the draft applied — its layer edits
    /// first (`layeredReach`, #2022); nil without a checklist.
    /// Memoized: every shortcut row reads it several times per
    /// render, and a Desktop switch re-renders them all.
    var encodedReach: RuleReachSnapshot? {
        let key = EncodedReachCache.Key(
            edits: reachEdits,
            appRules: config.appRules,
            floatRules: config.floatRules,
            layers: config.layers,
            scrollGesture: config.scrollGesture,
            gesture: config.gesture,
            spaceHistory: config.spaceHistory,
            focusWrap: config.focusWrap,
            modeCycle: config.modeCycle,
            tileRules: config.tileRules,
            floatAutomatically: config.floatAutomatically,
            tilingStart: config.settings.tiling.start,
            tilingOffHides: [
                config.settings.tiling.offHidesBorders,
                config.settings.tiling.offHidesBars,
            ],
            profile: reachProfile,
            isLoaded: reachIsLoaded,
            switchedBase: switchedShortcutBase,
            spaces: config.spaces
        )
        if let cache = encodedCache, cache.key == key { return cache.value }
        let value = encodeReach()
        encodedCache = EncodedReachCache(key: key, value: value)
        return value
    }

    /// The encode `encodedReach` memoizes, uncached.
    func encodeReach() -> RuleReachSnapshot? {
        guard var snapshot = layeredReach, let editing = reachProfile
        else { return nil }
        var pageTemplates: [String: KeyBinding] = [:]
        snapshot.appRules = RuleReachDraft.encode(
            snapshot.appRules,
            current: AppRuleOverride.normalized(config.appRules),
            editing: editing,
            isLoaded: reachIsLoaded,
            reach: reachEdits.reach[.space] ?? [:],
            removal: reachEdits.removal[.space] ?? [:]
        )
        snapshot.floatRules = RuleReachDraft.encode(
            snapshot.floatRules,
            current: RuleReachTable<[String]>.groupedByApp(
                config.floatRules
            ),
            editing: editing,
            isLoaded: reachIsLoaded,
            reach: reachEdits.reach[.float] ?? [:],
            removal: reachEdits.removal[.float] ?? [:]
        )
        let pageKeys = RuleReachTable<String>.combos(config.layers)
        RuleReachTable<String>.collectTemplates(
            config.layers,
            into: &pageTemplates
        )
        snapshot.keyTemplates.merge(pageTemplates) { _, page in page }
        snapshot.keyLayers = RuleReachDraft.encode(
            snapshot.keyLayers,
            current: pageKeys,
            editing: editing,
            isLoaded: reachIsLoaded,
            reach: LayerRowPicks.scoped(
                reachEdits.reach[.key] ?? [:],
                page: pageKeys,
                layers: snapshot.layerTable,
                keys: snapshot.keyLayers,
                editing: editing,
                isLoaded: reachIsLoaded
            ),
            removal: reachEdits.removal[.key] ?? [:]
        ) {
            $0.applyKey($1, value: $2, reach: $3, removal: $4, editing: $5)
        }
        snapshot.scrollGestures = RuleReachDraft.encode(
            snapshot.scrollGestures,
            current: config.scrollGesture.fields,
            editing: editing,
            isLoaded: reachIsLoaded,
            reach: reachEdits.reach[.scroll] ?? [:],
            removal: [:]
        )
        snapshot.gestures = RuleReachDraft.encode(
            snapshot.gestures,
            current: RuleReachTable<GestureAction>.gestureSeedsUnder(
                config.gesture
            ),
            editing: editing,
            isLoaded: reachIsLoaded,
            reach: reachEdits.reach[.gesture] ?? [:],
            removal: reachEdits.removal[.gesture] ?? [:]
        )
        snapshot.spaceHistory = RuleReachDraft.encode(
            snapshot.spaceHistory,
            current: [
                RuleReachTable<SpaceHistoryKind>.spaceHistoryKey:
                    config.spaceHistory
            ],
            editing: editing,
            isLoaded: reachIsLoaded,
            reach: reachEdits.reach[.history] ?? [:],
            removal: [:]
        )
        snapshot.focusWrap = RuleReachDraft.encode(
            snapshot.focusWrap,
            current: [
                RuleReachTable<FocusWrap>.focusWrapKey: config.focusWrap
            ],
            editing: editing,
            isLoaded: reachIsLoaded,
            reach: reachEdits.reach[.wrap] ?? [:],
            removal: [:]
        )
        snapshot.modeCycle = RuleReachDraft.encode(
            snapshot.modeCycle,
            current: [
                RuleReachTable<[LayoutMode]>.modeCycleKey:
                    config.modeCycle
            ],
            editing: editing,
            isLoaded: reachIsLoaded,
            reach: reachEdits.reach[.cycle] ?? [:],
            removal: [:]
        )
        snapshot.tileRules = RuleReachDraft.encode(
            snapshot.tileRules,
            current: RuleReachTable<[String]>.groupedByApp(
                config.tileRules.map(FloatGuess.normalizedRule)
            ),
            editing: editing,
            isLoaded: reachIsLoaded,
            reach: reachEdits.reach[.tile] ?? [:],
            removal: reachEdits.removal[.tile] ?? [:]
        )
        snapshot.floatAutomatically = RuleReachDraft.encode(
            snapshot.floatAutomatically,
            current: [
                RuleReachTable<Bool>.floatAutomaticallyKey:
                    config.floatAutomatically
            ],
            editing: editing,
            isLoaded: reachIsLoaded,
            reach: reachEdits.reach[.autoFloat] ?? [:],
            removal: [:]
        )
        snapshot.tilingStart = RuleReachDraft.encode(
            snapshot.tilingStart,
            current: tilingStartPage(
                config.settings.tiling,
                over: snapshot.tilingStart
            ),
            editing: editing,
            isLoaded: reachIsLoaded,
            reach: reachEdits.reach[.tilingStart] ?? [:],
            removal: [:]
        )
        snapshot.tilingOffHides = RuleReachDraft.encode(
            snapshot.tilingOffHides,
            current: tilingOffHidesPage(
                config.settings.tiling,
                over: snapshot.tilingOffHides
            ),
            editing: editing,
            isLoaded: reachIsLoaded,
            reach: reachEdits.reach[.tilingOffHides] ?? [:],
            removal: [:]
        )
        // The loaded page's gui.json layers, derived ONCE so the rule
        // write and the globals write read the same base.
        if reachIsLoaded {
            snapshot.pageKeyBase = snapshot.keyLayers.keyLayerBase(
                page: config.layers,
                editing: editing,
                storedPage: snapshot.storedKeyLayers(for: editing),
                storedBase: snapshot.storedKeyBase,
                templates: snapshot.keyTemplates
            )
        }
        return snapshot
    }

    /// Seeds the loaded profile's page with the rules it RESOLVES —
    /// the shared ones and its own — so the page shows what the
    /// screen does. The shared rules alone go back to gui.json,
    /// through `sidecarConfig`.
    func resolveLoadedRules(_ config: inout GuiConfig) {
        guard let stored = ruleReachStored, let loaded = reachPage,
            stored.appRules.profiles.contains(loaded)
        else { return }
        config.appRules = stored.appRules.resolved(for: loaded)
        config.floatRules = stored.floatRules.resolved(for: loaded)
            .sorted { $0.key < $1.key }
            .flatMap(\.value)
        config.layers = stored.storedKeyLayers(for: loaded)
        config.scrollGesture = stored.storedScrollBase.writing(
            stored.scrollGestures.resolved(for: loaded)
        )
        config.gesture = RuleReachTable<GestureAction>.gestureMap(
            over: stored.gestures.resolved(for: loaded)
        )
        config.spaceHistory =
            stored.spaceHistory.resolved(
                RuleReachTable<SpaceHistoryKind>.spaceHistoryKey,
                for: loaded
            ) ?? stored.spaceHistory.spaceHistoryBase
        config.focusWrap =
            stored.focusWrap.resolved(
                RuleReachTable<FocusWrap>.focusWrapKey,
                for: loaded
            ) ?? stored.focusWrap.focusWrapBase
        config.modeCycle =
            stored.modeCycle.resolved(
                RuleReachTable<[LayoutMode]>.modeCycleKey,
                for: loaded
            ) ?? stored.modeCycle.modeCycleBase
        config.tileRules = stored.tileRules.resolved(for: loaded)
            .sorted { $0.key < $1.key }
            .flatMap(\.value)
        config.floatAutomatically =
            stored.floatAutomatically.resolved(
                RuleReachTable<Bool>.floatAutomaticallyKey,
                for: loaded
            ) ?? stored.floatAutomatically.floatAutomaticallyBase
        // The page holds the loaded profile's own values, as its
        // file does (#3089).
        config.settings.tiling = encodedTilingToggle(
            config.settings.tiling,
            in: stored,
            for: loaded
        )
    }

    /// The draft as gui.json must hold it: on the live target the
    /// page's rules are the loaded profile's resolved set, so the
    /// shared rules are swapped back in. Every gui.json write of
    /// the draft goes through this.
    var sidecarConfig: GuiConfig {
        guard target == .live, let reach = encodedReach else {
            return config
        }
        var sidecar = config
        sidecar.appRules = reach.appRules.appRuleBase(
            original: reach.storedAppBase
        )
        sidecar.floatRules = reach.floatRules.floatRuleBase(
            original: reach.storedFloatBase
        )
        sidecar.layers = reach.keyBase
        sidecar.scrollGesture = reach.scrollGestures.scrollGestureBase(
            original: reach.storedScrollBase
        )
        sidecar.gesture = reach.gestures.gestureBase(
            original: reach.storedGestureBase
        )
        sidecar.spaceHistory = reach.spaceHistory.spaceHistoryBase
        sidecar.modeCycle = reach.modeCycle.modeCycleBase
        sidecar.focusWrap = reach.focusWrap.focusWrapBase
        sidecar.tileRules = reach.tileRules.floatRuleBase(
            original: reach.storedTileBase
        )
        sidecar.floatAutomatically =
            reach.floatAutomatically.floatAutomaticallyBase
        // The base is app-wide, stamped at the write; the page's own
        // values go back as the profile keeps them (#3089).
        if let page = reachProfile {
            sidecar.settings.tiling = encodedTilingToggle(
                config.settings.tiling,
                in: reach,
                for: page
            )
        }
        return sidecar
    }

    /// Takes a rule half that landed as the draft's baseline, so
    /// only what did not land stays unsaved.
    func adoptRuleHalf() {
        suppressDirty = true
        cleanConfig.appRules = config.appRules
        cleanConfig.floatRules = config.floatRules
        cleanConfig.scrollGesture = config.scrollGesture
        cleanConfig.gesture = config.gesture
        cleanConfig.spaceHistory = config.spaceHistory
        cleanConfig.modeCycle = config.modeCycle
        cleanConfig.focusWrap = config.focusWrap
        cleanConfig.tileRules = config.tileRules
        cleanConfig.floatAutomatically = config.floatAutomatically
        cleanConfig.settings.tiling = config.settings.tiling
        // Not the layers: a stored page's own shortcut diff is the
        // tiling write's, which is what failed.
        ruleReachStored = core.ruleReachSnapshot()
        reachEdits = RuleReachEdits()
        suppressDirty = false
        recomputeDirty()
    }

    /// Drops the draft's rule half, so a globals write after a
    /// failed or refused rule write carries the stored rules.
    func dropRuleHalf() {
        config.appRules = cleanConfig.appRules
        config.floatRules = cleanConfig.floatRules
        config.layers = cleanConfig.layers
        // Drafted beside the layers it moves (#1870): never kept
        // without them.
        config.shortcutBase = cleanConfig.shortcutBase
        config.scrollGesture = cleanConfig.scrollGesture
        config.gesture = cleanConfig.gesture
        config.spaceHistory = cleanConfig.spaceHistory
        config.modeCycle = cleanConfig.modeCycle
        config.focusWrap = cleanConfig.focusWrap
        config.tileRules = cleanConfig.tileRules
        config.floatAutomatically = cleanConfig.floatAutomatically
        config.settings.tiling = cleanConfig.settings.tiling
        reachEdits = RuleReachEdits()
    }
}
