import Foundation
import KiwiDeskCore

/// Dashboard edit target: live active config or stored profile (#64, #18).
enum EditTarget: Equatable {
    case live
    case storedProfile(String)
}

extension SettingsModel {
    /// Comprehensive edit target state snapshot (#64). The
    /// memberwise init forces both branches to assign every field
    /// — a new mode-dependent field breaks the build until both
    /// paths decide it.
    struct TargetState {
        var config: GuiConfig
        var luaSource: String
        var forcedLuaEditor: Bool
        var hasCustomLua: Bool
        var showLuaEditor: Bool
        var placementEditable: Bool
        var savedSidecar: GuiConfig?
        var profileEditingBaseLayers: [KeyLayer]?
        var keybindingWarning: String?
    }

    /// Switches the edit target. The loaded profile IS the live
    /// target (#1393): it is listed once, and its page reaches
    /// both the shared rules and its own through each rule's
    /// checklist, so no second door into it exists.
    func selectEditTarget(_ name: String?) {
        let normalized = Self.editTarget(name, loaded: activeProfile)
        guard normalized != target else { return }
        target = normalized
        reload()
    }

    /// The one mapping from a picked profile to a target.
    static func editTarget(_ name: String?, loaded: String?) -> EditTarget {
        guard let name, name != loaded else { return .live }
        return .storedProfile(name)
    }

    /// Reloads configuration and profile state from core into view model.
    func reload() {
        restoreLiveKeySessionIfNeeded()
        // A load can make the stored target the loaded one.
        // Core's name, not `activeProfile`, which `refreshProfiles`
        // updates only after this.
        target = Self.editTarget(
            editingProfile,
            loaded: core.profiles.currentName
        )
        ruleReachStored = core.ruleReachSnapshot()
        reachPage =
            ruleReachStored == nil
            ? nil : (editingProfile ?? core.profiles.currentName)
        let state: TargetState
        switch target {
        case .live:
            state = liveState()
        case .storedProfile(let name):
            if let stored = storedState(name) {
                state = stored
            } else {
                target = .live
                state = liveState()
            }
        }
        apply(state)
        suppressDirty = true
        reachEdits = RuleReachEdits()
        suppressDirty = false
        refreshProfiles()
        refreshPalettes()
        // Recompute, never hand-set: `apply` assigns under
        // `suppressDirty`, and a bare `isDirty = false` left
        // `draftChangeCount` stale (review 2026-08-04).
        recomputeDirty()
    }

    private func apply(_ state: TargetState) {
        if isDirty {
            HomeFirstRunState.retire(preferences)
        }
        suppressDirty = true
        config = state.config
        luaSource = state.luaSource
        suppressDirty = false
        seedSpaces = state.config.spaces
        cleanConfig = state.config
        cleanLuaSource = state.luaSource
        forcedLuaEditor = state.forcedLuaEditor
        hasCustomLua = state.hasCustomLua
        showLuaEditor = state.showLuaEditor
        placementEditable = state.placementEditable
        savedSidecar = state.savedSidecar
        profileEditingBaseLayers = state.profileEditingBaseLayers
        keybindingWarning = state.keybindingWarning
    }

    /// Assembles live target state with fallback for unseeded engine (#77,
    /// #326, #516).
    private func liveState() -> TargetState {
        var loaded = core.loadGuiConfig()
        // The live spaces overlay is authoritative — except in
        // the one recognisable state where it silently replaced
        // the authored list: the boot default of an AX-off cold
        // boot (#77, #326). Keyed on the DATA, since
        // `permissionPaused` arrives only after the first reload
        // (#516), and kept this narrow: a broader subset test
        // would resurrect a space deleted at runtime but unsaved.
        let bootDefault = [SpaceID(1)]
        if loaded.spaces == bootDefault,
            let persisted = core.persistedGuiConfig(),
            !persisted.spaces.isEmpty,
            persisted.spaces != bootDefault
        {
            loaded.spaces = persisted.spaces
        }
        resolveLoadedRules(&loaded)
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
            showLuaEditor: showLuaEditor,
            placementEditable: true,
            // Baseline for `globalsChanged`: the OVERLAID model,
            // never the raw sidecar — merged live state must not
            // read as a global edit, or a tiling-only save leaks
            // transient spaces into gui.json and init.lua.
            savedSidecar: core.isGuiManaged ? loaded : nil,
            profileEditingBaseLayers: nil,
            keybindingWarning: nil
        )
    }

    /// Loads stored profile state without activating (#18, #55, #109).
    private func storedState(_ name: String) -> TargetState? {
        guard
            var loaded = try? core.loadGuiConfig(editing: name)
        else { return nil }
        KeybindingImportClassifier.classify(&loaded)
        let live = displays.map(\.fingerprint)
        return TargetState(
            config: loaded,
            luaSource: "",
            // Mutually exclusive with the raw Lua editor — left
            // on, a global init.lua write escapes edit mode.
            forcedLuaEditor: false,
            hasCustomLua: false,
            showLuaEditor: false,
            placementEditable: (try? core.profiles.read(name: name))?
                .set(matching: live) != nil,
            savedSidecar: nil,
            // The same base the seed resolved onto (ONE
            // definition, `KiwiCore.baseKeyLayers`) — never the
            // resolved set the tabs edit (#55).
            profileEditingBaseLayers: core.baseKeyLayers(),
            keybindingWarning: nil
        )
    }

    /// Name of stored profile currently being edited, or nil if live (#64).
    var editingProfile: String? {
        if case .storedProfile(let name) = target {
            return name
        }
        return nil
    }

    /// Whether dashboard is editing a stored profile rather than live config
    /// (#18).
    var editingStoredProfile: Bool { target != .live }
}
