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
        // Rules need no VM — apply them before the Lua guard.
        applyStructuredRules(from: config)
        // Mint refs from the SAME interpreter that releases
        // them (`keys.lua`, see `KeybindingManager.reset`),
        // so mint and release cannot diverge.
        guard let lua = keys.lua else { return }
        applyStructuredKeybindings(
            modes: config.modes,
            profile: activeProfileModes(),
            lua: lua
        )
    }

    /// Re-registers keybindings for the profile being applied
    /// (#55 phase 6) WITHOUT re-applying rules — rules are
    /// global, not profile-scoped. Called from
    /// `apply(profile:)` / `apply(composed:)` so load_profile,
    /// dock/undock, and native-Space switches update binds.
    /// Takes the override explicitly: callers adopt AFTER
    /// applying, so `profiles.currentName` may still point at
    /// the previous profile here. Resets the active key mode
    /// to default (the mode set may change with the profile).
    /// No-op when not GUI-managed (Lua owns bindings, O7) or
    /// before the first `loadConfig` (no VM yet).
    func reapplyStructuredKeybindings(
        profileModes: KeyModeOverride?
    ) {
        guard isGuiManaged else { return }
        guard let config = loadStructuredConfig() else {
            return
        }
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
    private func loadStructuredConfig() -> GuiConfig? {
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

    /// Sets app rules, float rules, and native-space profile
    /// bindings directly from the GuiConfig — overrides what
    /// the managed block in `init.lua` set via Lua globals.
    private func applyStructuredRules(from config: GuiConfig) {
        state.appRules = config.appRules
        eventLoop.floatRules = FloatRules(config.floatRules)
        nativeSpaceBindings = config.profileBindings
    }

    // MARK: - Keybindings

    /// Resolves modes (base + profile override), resets the
    /// `keys` table (releasing the previous registration's
    /// refs), then registers the resolved bindings via
    /// `makeFunction`.
    private func applyStructuredKeybindings(
        modes base: [KeyMode],
        profile: KeyModeOverride?,
        lua: LuaInterpreter
    ) {
        let resolved = ConfigResolver.resolvedModes(
            base: base,
            profile: profile
        )
        // Reset releases managed-block refs (those refs belong
        // to `lua` too — VM-consistent). `keys.lua` is NOT
        // cleared; new refs minted below share the same VM.
        keys.reset()
        for mode in resolved {
            registerStructuredMode(mode, lua: lua)
        }
    }

    /// The active profile's `KeyModeOverride`, if any. A
    /// profile that exists but cannot be read degrades to the
    /// base bindings — loudly, matching the corrupt-gui.json
    /// policy above.
    private func activeProfileModes() -> KeyModeOverride? {
        guard let name = profiles.currentName else {
            return nil
        }
        guard let profile = try? profiles.read(name: name)
        else {
            onLog(
                "structured: active profile '\(name)' "
                    + "unreadable — base keybindings apply"
            )
            return nil
        }
        return profile.modes
    }

    /// Compiles and registers one mode's bindings via
    /// `makeFunction`. Empty combos are skipped silently (an
    /// empty combo is an unassigned GUI row, not an error);
    /// unparseable combos are logged and skipped. Compile
    /// errors skip the binding (not the whole mode) — parity
    /// with `KeybindingManager.fire` per-binding handling.
    private func registerStructuredMode(
        _ mode: KeyMode,
        lua: LuaInterpreter
    ) {
        var comboRefs: [KeyCombo: Int32] = [:]
        for binding in mode.bindings
        where !binding.combo.isEmpty {
            guard let combo = KeyCombo.parse(binding.combo)
            else {
                onLog(
                    "structured: invalid combo "
                        + "'\(binding.combo)'"
                )
                continue
            }
            switch lua.makeFunction(body: binding.lua) {
            case .success(let ref):
                // Duplicate combo within one mode: last wins;
                // release the displaced ref or it would orphan
                // a registry slot until the next reload.
                if let old = comboRefs.updateValue(
                    ref,
                    forKey: combo
                ) {
                    lua.release(ref: old)
                }
            case .failure(let err):
                onLog(
                    "structured: bind skipped "
                        + "[\(binding.combo)]: \(err)"
                )
            }
        }
        if mode.isDefault {
            for (combo, ref) in comboRefs {
                keys.bind(combo, ref: ref)
            }
        } else {
            keys.defineMode(
                mode.name,
                bindings: comboRefs,
                icon: mode.icon
            )
        }
    }
}
