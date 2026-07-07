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
        guard let config = guiConfigStore.load() else {
            // `isGuiManaged` implies the sidecar exists, so a
            // nil load means unreadable/corrupt JSON. Post
            // phase 5 no managed block stands behind it, so
            // this must stay loud, never a silent no-op.
            onLog(
                "structured: gui.json exists but could not "
                    + "be decoded — rules and keybindings "
                    + "unchanged"
            )
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
            lua: lua
        )
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

    /// Resolves modes (base + active profile override), resets
    /// the `keys` table (releasing managed-block refs), then
    /// registers the resolved bindings via `makeFunction`.
    private func applyStructuredKeybindings(
        modes base: [KeyMode],
        lua: LuaInterpreter
    ) {
        let resolved = ConfigResolver.resolvedModes(
            base: base,
            profile: activeProfileModes()
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
                comboRefs[combo] = ref
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
