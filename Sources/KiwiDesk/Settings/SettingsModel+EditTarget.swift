import Foundation
import KiwiDeskCore

/// The dashboard's edit target (#64): the live/active config,
/// or a stored profile edited without activating (#18). Total —
/// every mode-dependent field derives from this one value
/// through the single `reload()` below, so the two modes can
/// no longer drift apart field by field.
enum EditTarget: Equatable {
    case live
    case storedProfile(String)
}

extension SettingsModel {
    /// Every field the edit mode owns, decided as one unit.
    /// The memberwise init forces both branches to assign every
    /// field — adding a mode-dependent field here breaks the
    /// build until both `liveState()` and `storedState(_:)`
    /// decide it (#64; the round-1 #18 defects were exactly a
    /// forgotten field on one of two hand-kept paths).
    struct TargetState {
        var config: GuiConfig
        var luaSource: String
        var forcedLuaEditor: Bool
        var hasCustomLua: Bool
        var showLuaEditor: Bool
        var placementEditable: Bool
        var savedSidecar: GuiConfig?
        var profileEditingBaseModes: [KeyMode]?
        var profileEditingBaseAppRules: [String: SpaceID]?
        var profileEditingBaseFloatRules: [String]?
        var keybindingWarning: String?
    }

    /// Switches the dashboard's edit target. Passing `nil`
    /// returns to live editing; any saved profile name — the
    /// currently-loaded one included (#209) — enters edit-
    /// without-activating mode on that profile's stored
    /// overrides. Editing the loaded profile is a real target,
    /// not a synonym for Live: saving it re-applies in place
    /// (`saveEditedProfile` → `reapplyIfInEffect`), which Live's
    /// adopt-on-save path does not do. Pending edits are
    /// discarded — the caller confirms first.
    func selectEditTarget(_ name: String?) {
        let normalized: EditTarget =
            name.map { .storedProfile($0) } ?? .live
        guard normalized != target else { return }
        target = normalized
        reload()
    }

    /// Pulls the current configuration and profile state from
    /// the core into the view model (discards unsaved edits).
    /// ONE path for both targets: each branch produces a full
    /// `TargetState`, applied wholesale.
    func reload() {
        restoreLiveKeySessionIfNeeded()
        let state: TargetState
        switch target {
        case .live:
            state = liveState()
        case .storedProfile(let name):
            if let stored = storedState(name) {
                state = stored
            } else {
                // The profile vanished mid-edit — fall back
                // to live editing.
                target = .live
                state = liveState()
            }
        }
        apply(state)
        refreshProfiles()
        isDirty = false
    }

    private func apply(_ state: TargetState) {
        suppressDirty = true
        config = state.config
        luaSource = state.luaSource
        suppressDirty = false
        seedSpaces = state.config.spaces
        // The dirty baselines: `isDirty` is a live comparison
        // against the as-applied state, so manually undoing
        // an edit reads as clean again.
        cleanConfig = state.config
        cleanLuaSource = state.luaSource
        forcedLuaEditor = state.forcedLuaEditor
        hasCustomLua = state.hasCustomLua
        showLuaEditor = state.showLuaEditor
        placementEditable = state.placementEditable
        savedSidecar = state.savedSidecar
        profileEditingBaseModes = state.profileEditingBaseModes
        profileEditingBaseAppRules =
            state.profileEditingBaseAppRules
        profileEditingBaseFloatRules =
            state.profileEditingBaseFloatRules
        keybindingWarning = state.keybindingWarning
    }

    private func liveState() -> TargetState {
        var loaded = core.loadGuiConfig()
        // `loadGuiConfig` overlays `spaces` from LIVE state, and
        // in a started engine that overlay is authoritative — it
        // carries the chosen display ORDER, and a space living
        // only in `gui.json` was seeded into live at boot (#77).
        //
        // It is untrusted in exactly one recognisable state:
        // live holds ONLY `StateCoordinator`'s boot default, the
        // shape of an Accessibility-off cold boot where the
        // engine never started and so never seeded. The overlay
        // has then silently replaced the authored list with
        // `["1"]`, and the authored one is the only safe read.
        // #326 hit the same hazard and fixed it the same way.
        //
        // Keyed on the DATA, not on `permissionPaused`: that
        // flag is pushed in by `setPermissionPaused` AFTER
        // `SettingsModel.init` has run its first `reload()`, so
        // gating on it would leave the very first seed
        // degenerate — and before #516 that only mis-displayed,
        // while a globals save now PERSISTS what was seeded.
        //
        // Kept narrow on purpose. A broader "is the authored
        // list a subset of live?" test also fires in a HEALTHY
        // engine — a space deleted at runtime but not yet saved
        // is absent from live and present in the sidecar — and
        // would resurrect it in the editor.
        let bootDefault = [SpaceID(1)]
        if loaded.spaces == bootDefault,
            let persisted = core.persistedGuiConfig(),
            !persisted.spaces.isEmpty,
            persisted.spaces != bootDefault
        {
            loaded.spaces = persisted.spaces
        }
        // Recovered rows arrive as `.custom`; sort the ones
        // that match a catalog action into their sections
        // before the tabs render them (#4).
        KeybindingImportClassifier.classify(&loaded)
        let source =
            (try? String(
                contentsOf: configURL,
                encoding: .utf8
            )) ?? ""
        let flags = ManagedConfig.classify(source)
        return TargetState(
            config: loaded,
            luaSource: source,
            forcedLuaEditor: flags.foreign,
            hasCustomLua: !flags.foreign && flags.custom,
            // The user's raw-editor toggle survives a live
            // reload (Revert keeps the editor open).
            showLuaEditor: showLuaEditor,
            placementEditable: true,
            // Baseline for `globalsChanged`: the *overlaid*
            // model, not the raw sidecar — live profile state
            // merged in (e.g. composed monocle-fill spaces in
            // the spaces union) must not read as a global
            // edit, or a tiling-only save would regenerate
            // gui.json and init.lua and leak transient spaces
            // into them. Accepted edges: a genuine global
            // edit still saves the overlaid spaces union, and
            // deleting + re-adding a transient space alone
            // doesn't read as an edit.
            savedSidecar: core.isGuiManaged ? loaded : nil,
            profileEditingBaseModes: nil,
            profileEditingBaseAppRules: nil,
            profileEditingBaseFloatRules: nil,
            // A reload discards the edits the banner was
            // about; batch paths (Lua save, Adopt) re-derive
            // it right after via `warnIfAnyConflict`.
            keybindingWarning: nil
        )
    }

    /// Edit-without-activating (#18): seed the tabs from a
    /// stored profile's JSON instead of live state. Stored-
    /// profile edits never touch the raw Lua editor or the
    /// global sidecar — only the profile JSON is written.
    /// nil when the profile is unreadable.
    private func storedState(_ name: String) -> TargetState? {
        guard
            var loaded = try? core.loadGuiConfig(editing: name)
        else { return nil }
        KeybindingImportClassifier.classify(&loaded)
        let live = displays.map(\.fingerprint)
        return TargetState(
            config: loaded,
            luaSource: "",
            // Stored-profile editing is mutually exclusive
            // with the raw Lua editor — leaving it on would
            // let a global init.lua write escape edit mode.
            forcedLuaEditor: false,
            hasCustomLua: false,
            showLuaEditor: false,
            // The Canvas is editable only when the profile
            // covers the connected monitors — otherwise there
            // is no live geometry to render (#18).
            placementEditable: (try? core.profiles.read(name: name))?
                .set(matching: live) != nil,
            savedSidecar: nil,
            // Diff baseline for the override-mode Shortcuts
            // tab (#55 phase 7): the same base the seed
            // resolved onto (ONE definition,
            // `KiwiCore.baseKeyModes`) — never the resolved
            // set the tabs edit.
            profileEditingBaseModes: core.baseKeyModes(),
            // Same baseline role for the App Rules tab's
            // space-facet override (#109).
            profileEditingBaseAppRules: core.baseAppRules(),
            profileEditingBaseFloatRules: core.baseFloatRules(),
            keybindingWarning: nil
        )
    }
}
