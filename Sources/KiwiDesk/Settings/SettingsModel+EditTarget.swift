import Foundation
import KiwiDeskCore

/// Dashboard edit target: live active config or stored profile (#64, #18).
enum EditTarget: Equatable {
    case live
    case storedProfile(String)
}

extension SettingsModel {
    /// Comprehensive edit target state snapshot (#64).
    struct TargetState {
        var config: GuiConfig
        var luaSource: String
        var forcedLuaEditor: Bool
        var hasCustomLua: Bool
        var showLuaEditor: Bool
        var placementEditable: Bool
        var savedSidecar: GuiConfig?
        var profileEditingBaseLayers: [KeyLayer]?
        var profileEditingBaseAppRules: [String: SpaceID]?
        var profileEditingBaseFloatRules: [String]?
        var keybindingWarning: String?
    }

    /// Switches dashboard edit target between live config and stored profile
    /// (#209).
    func selectEditTarget(_ name: String?) {
        let normalized: EditTarget =
            name.map { .storedProfile($0) } ?? .live
        guard normalized != target else { return }
        target = normalized
        reload()
    }

    /// Reloads configuration and profile state from core into view model.
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
                target = .live
                state = liveState()
            }
        }
        apply(state)
        refreshProfiles()
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
        profileEditingBaseAppRules =
            state.profileEditingBaseAppRules
        profileEditingBaseFloatRules =
            state.profileEditingBaseFloatRules
        keybindingWarning = state.keybindingWarning
    }

    /// Assembles live target state with fallback for unseeded engine (#77,
    /// #326, #516).
    private func liveState() -> TargetState {
        var loaded = core.loadGuiConfig()
        let bootDefault = [SpaceID(1)]
        if loaded.spaces == bootDefault,
            let persisted = core.persistedGuiConfig(),
            !persisted.spaces.isEmpty,
            persisted.spaces != bootDefault
        {
            loaded.spaces = persisted.spaces
        }
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
            savedSidecar: core.isGuiManaged ? loaded : nil,
            profileEditingBaseLayers: nil,
            profileEditingBaseAppRules: nil,
            profileEditingBaseFloatRules: nil,
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
            forcedLuaEditor: false,
            hasCustomLua: false,
            showLuaEditor: false,
            placementEditable: (try? core.profiles.read(name: name))?
                .set(matching: live) != nil,
            savedSidecar: nil,
            profileEditingBaseLayers: core.baseKeyLayers(),
            profileEditingBaseAppRules: core.baseAppRules(),
            profileEditingBaseFloatRules: core.baseFloatRules(),
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
