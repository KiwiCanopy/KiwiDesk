import Foundation

/// Structured (GUI-direct) config application (#55 phase 4).
/// Runs AFTER `init.lua` in `loadConfig()` when GUI-managed.
/// Reads rules and keybindings directly from `gui.json` and
/// the active profile's sparse overrides — no Lua intermediary.
///
/// Double-registration prevention: this function calls
/// `keys.reset()` before registering, which releases the refs
/// the managed block minted from `init.lua`. Exactly one set of
/// refs exists after this function returns. `keys.lua` is NOT
/// cleared by `reset()`, so new refs minted here via
/// `lua.makeFunction` belong to the same VM — VM-safe (#5).
///
/// When not GUI-managed, this function is a no-op and
/// `applyConfigGlobals` (Lua-declared) stays authoritative.
extension KiwiCore {
    // MARK: - Entry point

    /// Applies rules and keybindings directly from `GuiConfig`
    /// (+ active profile `KeyLayerOverride`) when GUI-managed.
    /// A no-op otherwise.
    func applyStructuredConfig() {
        guard isGuiManaged else { return }
        guard let config = loadStructuredConfig() else {
            return
        }
        // ONE profile read for both override tiers (#55/#109).
        let profile = activeProfileOverrides()
        // Rules need no VM — apply them before the Lua guard.
        applyStructuredRules(
            from: config,
            appRules: profile?.appRules,
            floatRules: profile?.floatRules,
            ignoreRules: profile?.ignoreRules
        )
        // Mint refs from the SAME interpreter that releases
        // them (`keys.lua`, see `KeybindingManager.reset`),
        // so mint and release cannot diverge.
        guard let lua = keys.lua else { return }
        applyStructuredKeybindings(
            layers: config.layers,
            profile: profile?.layers,
            lua: lua
        )
    }

    /// Re-applies the profile's behavior overrides from one
    /// sidecar decode: keybindings and all window-rule families.
    /// Called from `apply(profile:)` / `apply(composed:)` so
    /// load_profile, dock/undock, and native-Space switches
    /// update both. Takes the overrides explicitly: callers
    /// adopt AFTER applying, so `profiles.currentName` may
    /// still point at the previous profile here. Resets the
    /// active key mode to default (the set may change with the
    /// profile). Window-rule overrides apply for either global
    /// owner; only the keybinding half is GUI-managed and needs
    /// a live VM.
    func reapplyStructuredOverrides(
        profileModes: KeyLayerOverride?,
        profileAppRules: AppRuleOverride?,
        profileFloatRules: RuleListOverride?,
        profileIgnoreRules: RuleListOverride?
    ) {
        var structured: GuiConfig?
        if isGuiManaged {
            guard let config = loadStructuredConfig() else {
                return
            }
            structured = config
            captureGlobalWindowRuleBase(from: config)
        }
        setResolvedWindowRules(
            appRules: profileAppRules,
            floatRules: profileFloatRules,
            ignoreRules: profileIgnoreRules
        )
        guard isGuiManaged else { return }
        guard let lua = keys.lua else { return }
        guard let config = structured else { return }
        applyStructuredKeybindings(
            layers: config.layers,
            profile: profileModes,
            lua: lua
        )
    }

    /// Loads the sidecar, logging loudly when it exists but
    /// cannot be decoded (`isGuiManaged` implies existence, so
    /// nil here means unreadable/corrupt JSON — post phase 5
    /// nothing stands behind it; never a silent no-op).
    /// Internal: shared with `liveApplyKeybindings` (#123).
    func loadStructuredConfig() -> GuiConfig? {
        if let config = guiConfigStore.load() {
            return config
        }
        onLog(
            "structured: gui.json unreadable — rules and "
                + "keybindings unavailable until it is "
                + "fixed or deleted"
        )
        return nil
    }

    // MARK: - Rules

    /// Sets window rules and native-space profile bindings
    /// directly from GuiConfig — overrides what the managed
    /// block in `init.lua` set via Lua globals. Each rule family
    /// resolves through the active profile's sparse override.
    private func applyStructuredRules(
        from config: GuiConfig,
        appRules: AppRuleOverride?,
        floatRules: RuleListOverride?,
        ignoreRules: RuleListOverride?
    ) {
        captureGlobalWindowRuleBase(from: config)
        setResolvedWindowRules(
            appRules: appRules,
            floatRules: floatRules,
            ignoreRules: ignoreRules
        )
        nativeSpaceBindings = config.profileBindings
    }

    func captureGlobalWindowRuleBase(from config: GuiConfig) {
        captureGlobalWindowRuleBase(
            appRules: config.appRules,
            floatRules: config.floatRules,
            ignoreRules: config.ignoreRules
        )
    }

    func captureGlobalWindowRuleBase(
        appRules: [String: SpaceID],
        floatRules: [String],
        ignoreRules: [String]
    ) {
        globalAppRuleBase = AppRuleOverride.normalized(appRules)
        globalFloatRuleBase = FloatRules(floatRules).rawRules
        globalIgnoreRuleBase = IgnoreRules(ignoreRules).rawRules
    }

    private func setResolvedWindowRules(
        appRules: AppRuleOverride?,
        floatRules: RuleListOverride?,
        ignoreRules: RuleListOverride?
    ) {
        setResolvedAppRules(
            base: globalAppRuleBase,
            override: appRules
        )
        let resolvedFloat =
            floatRules?.resolved(
                onto: globalFloatRuleBase,
                normalizing: FloatRules.normalizedRule
            ) ?? globalFloatRuleBase
        let resolvedIgnore =
            ignoreRules?.resolved(
                onto: globalIgnoreRuleBase,
                normalizing: IgnoreRules.normalizedRule
            ) ?? globalIgnoreRuleBase
        eventLoop.floatRules = FloatRules(resolvedFloat)
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
    /// thing to run twice, and boot ran it twice: the chunked
    /// scan's epilogue publishes displays from inside
    /// `scanChunk`, the monitor-change handler loads the matching
    /// profile, and that profile's window rules land here — a
    /// second full pass over every app, still inside the boot
    /// phase and billed to the boot summary's `scan` figure. One
    /// AX-unresponsive helper was therefore paid for twice: a
    /// 10.3 s `scan` figure against a 4.9 s scan (#836).
    ///
    /// Two callers skip it, and neither loses the re-check:
    ///
    /// - `defersWindowRuleReconcile` — `loadConfig` writes the
    ///   rules several times over and runs one pass itself
    ///   afterwards.
    /// - **the boot scan is still open** — `finishBoot` schedules
    ///   the startup sweep, which mirrors `reconcileAll`'s two
    ///   loops per app, chunked and budgeted
    ///   (`EventLoop.beginSweep`), against these very rules, one
    ///   second later. That is the dependency this skip rests on,
    ///   so it is pinned rather than promised here:
    ///   `StartupSweepTests` pins the sweep doing the work and
    ///   `StartupSweepWiringTests` pins the boot tail still
    ///   scheduling it.
    ///
    /// Deliberately NOT widened to "any open pass". The startup
    /// sweep publishes no displays, so a monitor change arriving
    /// during one is a change the user just made, with no later
    /// pass behind it to heal a skip.
    private var mayReconcileWindowRulesNow: Bool {
        !defersWindowRuleReconcile && !boot.phase.isStarting
    }

    /// The one write of the resolved app-rule tier — shared by
    /// the full apply and the profile re-apply, mirroring how
    /// both keybinding entry points funnel through
    /// `applyStructuredKeybindings`.
    private func setResolvedAppRules(
        base: [String: SpaceID],
        override: AppRuleOverride?
    ) {
        state.appRules = ConfigResolver.resolvedAppRules(
            base: base,
            profile: override
        )
    }

    /// The active profile, read once for its override tiers.
    /// A profile that exists but cannot
    /// be read degrades to the base config — loudly, matching
    /// the corrupt-gui.json policy above.
    /// Internal: shared with `liveApplyKeybindings` (#123).
    func activeProfileOverrides() -> Profile? {
        guard let name = profiles.currentName else {
            return nil
        }
        guard let profile = try? profiles.read(name: name)
        else {
            onLog(
                "structured: active profile '\(name)' "
                    + "unreadable — base config applies"
            )
            return nil
        }
        return profile
    }

}
