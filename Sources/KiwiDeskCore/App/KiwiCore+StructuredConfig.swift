import Foundation

/// Structured (GUI-direct) config application (#55 phase 4).
/// Runs AFTER `init.lua` in `loadConfig()` when GUI-managed.
/// Reads rules and keybindings directly from `gui.json` and
/// the active profile's `KeyModeOverride` — no Lua intermediary.
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
    /// (+ active profile `KeyModeOverride`) when GUI-managed.
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
            appRules: profile?.appRules
        )
        // Mint refs from the SAME interpreter that releases
        // them (`keys.lua`, see `KeybindingManager.reset`),
        // so mint and release cannot diverge.
        guard let lua = keys.lua else { return }
        applyStructuredKeybindings(
            modes: config.modes,
            profile: profile?.modes,
            lua: lua
        )
    }

    /// Re-applies BOTH per-profile override tiers for the
    /// profile being applied — keybindings (#55 phase 6) and
    /// app→space rules (#109) — from ONE sidecar decode.
    /// Called from `apply(profile:)` / `apply(composed:)` so
    /// load_profile, dock/undock, and native-Space switches
    /// update both. Takes the overrides explicitly: callers
    /// adopt AFTER applying, so `profiles.currentName` may
    /// still point at the previous profile here. Float/ignore
    /// rules and native-space bindings stay global — never
    /// touched here. Resets the active key mode to default (the
    /// set may change with the profile). No-op when not
    /// GUI-managed (Lua owns the config, O7); the keybinding
    /// half additionally no-ops before the first `loadConfig`
    /// (no VM yet), while rules need no VM.
    func reapplyStructuredOverrides(
        profileModes: KeyModeOverride?,
        profileAppRules: AppRuleOverride?
    ) {
        guard isGuiManaged else { return }
        guard let config = loadStructuredConfig() else {
            return
        }
        setResolvedAppRules(
            base: config.appRules,
            override: profileAppRules
        )
        guard let lua = keys.lua else { return }
        applyStructuredKeybindings(
            modes: config.modes,
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

    /// Sets app rules, float/ignore rules, and native-space
    /// profile bindings directly from GuiConfig — overrides what
    /// the managed block in `init.lua` set via Lua globals.
    /// App rules resolve through the active profile's sparse
    /// override (#109); the rest is global.
    private func applyStructuredRules(
        from config: GuiConfig,
        appRules override: AppRuleOverride?
    ) {
        setResolvedAppRules(
            base: config.appRules,
            override: override
        )
        eventLoop.floatRules = FloatRules(config.floatRules)
        eventLoop.ignoreRules = IgnoreRules(config.ignoreRules)
        nativeSpaceBindings = config.profileBindings
    }

    /// The one write of the resolved app-rule tier — shared by
    /// the full apply and the profile re-apply, mirroring how
    /// both keybinding entry points funnel through
    /// `applyStructuredKeybindings`.
    private func setResolvedAppRules(
        base: [String: SpaceID],
        override: AppRuleOverride?
    ) {
        let resolved = ConfigResolver.resolvedAppRules(
            base: base,
            profile: override
        )
        // Key by lower-cased bundle id to match the normalized
        // `ManagedWindow.appBundleID` (case-insensitive, like
        // LaunchServices). Last write wins on a case collision —
        // bundle ids never legitimately differ only by case.
        state.appRules = Dictionary(
            resolved.map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    /// The active profile, read once for its override tiers
    /// (`modes`, `appRules`). A profile that exists but cannot
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
