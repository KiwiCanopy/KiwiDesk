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
        applyStructuredRules(from: config)
        applyBehaviorOverrides(base: config, profile: profile)
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

    /// Re-applies `profile`'s behaviour overrides — every family
    /// `applyBehaviorOverrides` resolves, then the shortcuts — from
    /// one sidecar decode; nil (a composed Standard) is the base.
    /// Called from `apply(profile:)` / `apply(composed:)`, which
    /// adopt AFTER applying, so the profile is passed rather than
    /// read from `profiles.currentName`. Resets the active key mode
    /// to default. The families resolve for either config owner;
    /// only the shortcuts are GUI-managed and need a live VM.
    func reapplyStructuredOverrides(_ profile: Profile?) {
        var structured: GuiConfig?
        if isGuiManaged {
            guard let config = loadStructuredConfig() else {
                return
            }
            structured = config
        }
        // Resolves over either owner: the sidecar's base, or the
        // one `init.lua`'s verbs left in hand.
        applyBehaviorOverrides(base: structured, profile: profile)
        guard isGuiManaged else { return }
        guard let lua = keys.lua else { return }
        guard let config = structured else { return }
        applyStructuredKeybindings(
            layers: config.layers,
            profile: profile?.layers,
            lua: lua
        )
    }

    /// Loads the sidecar, logging loudly when it exists but
    /// cannot be decoded (`isGuiManaged` implies existence, so
    /// nil here means unreadable/corrupt JSON — post phase 5
    /// nothing stands behind it; never a silent no-op).
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

    /// The active profile, read once for its override tiers.
    /// A profile that exists but cannot
    /// be read degrades to the base config — loudly, matching
    /// the corrupt-gui.json policy above.
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
