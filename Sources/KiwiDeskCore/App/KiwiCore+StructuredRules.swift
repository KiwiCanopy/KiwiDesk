import Foundation

/// The window-rule half of the structured apply (#55, #109):
/// the global bases and their resolve through the active
/// profile's sparse overrides.
extension KiwiCore {
    // MARK: - Rules

    /// Sets window rules and native-space profile bindings
    /// directly from GuiConfig — overrides what the managed
    /// block in `init.lua` set via Lua globals. Each rule family
    /// resolves through the active profile's sparse override.
    func applyStructuredRules(
        from config: GuiConfig,
        profile: WindowRuleOverrides
    ) {
        captureGlobalWindowRuleBase(from: config)
        setResolvedWindowRules(profile)
        desktopBindings = config.profileBindings
        // #1230: what each Desktop was showing, so a restart does
        // not re-scatter them.
        adoptPersistedDesktopSpaces(config.desktopSpaces)
    }

    func captureGlobalWindowRuleBase(from config: GuiConfig) {
        captureGlobalWindowRuleBase(
            appRules: config.appRules,
            floatRules: config.floatRules,
            ignoreRules: config.ignoreRules,
            tileRules: config.tileRules,
            floatAutomatically: config.floatAutomatically
        )
    }

    func captureGlobalWindowRuleBase(
        appRules: [String: SpaceID],
        floatRules: [String],
        ignoreRules: [String],
        tileRules: [String],
        floatAutomatically: Bool
    ) {
        globalRuleBase.appRules = AppRuleOverride.normalized(appRules)
        globalRuleBase.floatRules = FloatRules(floatRules).rawRules
        globalRuleBase.ignoreRules = IgnoreRules(ignoreRules).rawRules
        globalRuleBase.tileRules = IgnoreRules(tileRules).rawRules
        globalRuleBase.floatAutomatically = floatAutomatically
    }

    /// Re-resolves the window rules and the shortcuts from the
    /// stored base and the active profile's file, touching nothing
    /// else — the tail of a rule write that changed no other
    /// setting (#1393). Shortcuts re-register only when `keys`,
    /// in the running layer rather than the default one.
    func refreshStructuredOverrides(keys changed: Bool) {
        guard isGuiManaged, let config = loadStructuredConfig() else {
            return
        }
        let profile = activeProfileOverrides()
        captureGlobalWindowRuleBase(from: config)
        setResolvedWindowRules(WindowRuleOverrides(profile))
        applyScrollGestures(
            base: config.scrollGesture,
            profile: profile?.scrollGesture
        )
        applySpaceHistory(
            base: config.spaceHistory,
            profile: profile?.spaceHistory
        )
        guard changed, let lua = keys.lua else { return }
        applyStructuredKeybindings(
            layers: config.layers,
            profile: profile?.layers,
            lua: lua,
            preferredLayer: keys.currentLayer
        )
    }

    func setResolvedWindowRules(_ profile: WindowRuleOverrides) {
        setResolvedAppRules(
            base: globalRuleBase.appRules,
            override: profile.appRules
        )
        let resolvedFloat =
            profile.floatRules?.resolved(
                onto: globalRuleBase.floatRules,
                normalizing: FloatRules.normalizedRule
            ) ?? globalRuleBase.floatRules
        let resolvedIgnore =
            profile.ignoreRules?.resolved(
                onto: globalRuleBase.ignoreRules,
                normalizing: IgnoreRules.normalizedRule
            ) ?? globalRuleBase.ignoreRules
        let resolvedTile =
            profile.tileRules?.resolved(
                onto: globalRuleBase.tileRules,
                normalizing: IgnoreRules.normalizedRule
            ) ?? globalRuleBase.tileRules
        eventLoop.floatRules = FloatRules(
            resolvedFloat,
            guess: FloatGuess(
                enabled: profile.floatAutomatically
                    ?? globalRuleBase.floatAutomatically,
                tileRules: resolvedTile
            )
        )
        eventLoop.ignoreRules = IgnoreRules(resolvedIgnore)
        if mayReconcileWindowRulesNow {
            eventLoop.reconcileAll()
        }
    }

    /// Whether a window-rule write may re-check every app from
    /// this call site, or must leave that to a pass that already
    /// will.
    ///
    /// `reconcileAll` is unchunked and unbudgeted on purpose —
    /// the per-app budget is raised for a queued STEP and never
    /// for a pass, so an OS- or config-driven reconcile is never
    /// cut short (accessibility.md). That makes it the wrong
    /// thing to run twice, and boot ran it twice (#836); the two
    /// flags below are each a caller saying "not from here".
    ///
    /// - `defersWindowRuleReconcile` — `loadConfig` writes the
    ///   rules several times over and runs one pass itself
    ///   afterwards.
    /// - `defersWindowRuleReconcileToSweep` — boot. It is a flag
    ///   raised in `start()` and lowered beside the sweep's arm,
    ///   NOT a read of `BootPhase`: the phase is a readiness
    ///   signal for the menu and the tour, under the opposite
    ///   pressure (narration wants `.ready` as early as honest,
    ///   this wants it no earlier than the tail), so keying on it
    ///   would let a later "brighten the mark once the first
    ///   arrangement lands" change silently re-open the defect
    ///   (architect review, 2026-08-13). What heals it is TWO
    ///   passes, not one. The startup sweep mirrors
    ///   `reconcileAll`'s two loops per app chunked and budgeted
    ///   (`EventLoop.beginSweep`), and `drainDeferredBootApps`
    ///   covers what the sweep cannot: `perform` skips an app on
    ///   `bootScan.unresponsiveApps` outright, which is exactly
    ///   the AX-unresponsive helper #836 measured. Naming only
    ///   the sweep would leave that app's re-check promised by
    ///   nothing. `StartupSweepTests` and `StartupSweepWiringTests`
    ///   pin the sweep and its arming; `BootPhaseTests` drives the
    ///   drain.
    ///
    /// **What the deferral costs.** Not only late discovery — the
    /// skipped pass also re-CLASSIFIES windows already tracked,
    /// since `recheckFloat` stores a float verdict per window at
    /// reconcile time rather than reading the rules at retile. So
    /// where a boot-time profile load genuinely changes a rule
    /// family, `finishBoot`'s retile and session restore run
    /// under the previous verdicts and the desk re-settles when
    /// the healing pass lands, after the mark says ready. Late
    /// discovery is the milder half but not free either: `adopt`
    /// files an unseen snapshot window through `remember(_:in:)`,
    /// which returns it to its SPACE and not to its slot — and
    /// the array order is the layout order, which is what
    /// `restore` exists for.
    ///
    /// And `reconcileAll` is not only rule work at all: it also
    /// runs `syncObservation` per running app and a full
    /// `reconcile` per observed pid, so this defers window
    /// discovery, the destroy sweep and `repairRegistration()`
    /// for a refused-observer app (#675) along with the rules.
    /// All three are backstopped — the sweep and the drain cover
    /// the first two, `healSweep` the third — which is why the
    /// deferral is bounded to boot, where those passes are about
    /// to run anyway, and is NOT extended to a steady-state apply
    /// where nothing is queued behind it. Everything visible from
    /// this is the residue `docs/accepted-limitations.md` carries
    /// a row for.
    ///
    /// An earlier draft skipped the pass whenever the resolved
    /// rules were UNCHANGED. It is gone, and it is worth saying
    /// why so it is not re-proposed: at boot it changed nothing
    /// (the deferral already skips, rules changed or not), and
    /// everywhere else it silently dropped the three non-rule
    /// halves above from every no-op profile apply — a
    /// steady-state change with none of #836's evidence behind
    /// it (code review, 2026-08-13).
    ///
    /// Deliberately NOT widened to "any open pass". The startup
    /// sweep publishes no displays, so a monitor change arriving
    /// during one is a change the user just made, with no later
    /// pass behind it to heal a skip.
    var mayReconcileWindowRulesNow: Bool {
        !defersWindowRuleReconcile
            && !defersWindowRuleReconcileToSweep
    }

    /// The one write of the resolved app-rule tier — shared by
    /// the full apply and the profile re-apply, mirroring how
    /// both keybinding entry points funnel through
    /// `applyStructuredKeybindings`.
    func setResolvedAppRules(
        base: [String: SpaceID],
        override: AppRuleOverride?
    ) {
        state.appRules = ConfigResolver.resolvedAppRules(
            base: base,
            profile: override
        )
    }
}

/// A profile's sparse overrides of the window-rule families, read
/// together so a resolve cannot leave one behind.
struct WindowRuleOverrides {
    var appRules: AppRuleOverride?
    var floatRules: RuleListOverride?
    var ignoreRules: RuleListOverride?
    /// `tile_rules` and `float_automatically` (#2173).
    var tileRules: RuleListOverride?
    var floatAutomatically: Bool?
}

extension WindowRuleOverrides {
    /// `profile`'s overrides; none for no profile.
    init(_ profile: Profile?) {
        self.init(
            appRules: profile?.appRules,
            floatRules: profile?.floatRules,
            ignoreRules: profile?.ignoreRules,
            tileRules: profile?.tileRules,
            floatAutomatically: profile?.floatAutomatically
        )
    }
}
