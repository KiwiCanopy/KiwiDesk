import Foundation
import KiwiDeskCore

/// The stored-profile editing surface of the dashboard model
/// (#18, #55 phase 7): the edit-mode reload path and the
/// Shortcuts tab's override-mode baseline/affordance helpers.
extension SettingsModel {
    /// Reload path for the profile-dropdown edit mode (#18):
    /// seed the tabs from a stored profile's JSON instead of
    /// live state. A profile that has vanished falls back to
    /// live editing. Stored-profile edits never touch the raw
    /// Lua editor or the global sidecar — only the profile
    /// JSON is written — so `savedSidecar` is cleared.
    func reloadEditingProfile(_ name: String) {
        guard var loaded = try? core.loadGuiConfig(editing: name)
        else {
            editingProfile = nil
            reload()
            return
        }
        suppressDirty = true
        KeybindingImportClassifier.classify(&loaded)
        config = loaded
        suppressDirty = false
        // Diff baseline for the override-mode Shortcuts tab
        // (#55 phase 7): the same base the seed resolved onto
        // (ONE definition, `KiwiCore.baseKeyModes`) — never
        // the resolved set the tabs edit.
        profileEditingBaseModes = core.baseKeyModes()
        // Stored-profile editing is mutually exclusive with the
        // raw Lua editor — leaving it on would let a global
        // init.lua write escape edit mode.
        forcedLuaEditor = false
        hasCustomLua = false
        showLuaEditor = false
        savedSidecar = nil
        let live = displays.map(\.fingerprint)
        placementEditable =
            (try? core.profiles.read(name: name))?
            .set(matching: live) != nil
        refreshProfiles()
        isDirty = false
    }

    // MARK: - Override-mode Shortcuts affordance (#55)

    /// The selected mode's base rows for the Shortcuts tab's
    /// override affordance; nil during live editing, empty
    /// when the mode only exists in the profile.
    func overrideBaseRows(mode name: String) -> [KeyBinding]? {
        guard let base = profileEditingBaseModes else {
            return nil
        }
        return base.first { $0.name == name }?.bindings ?? []
    }

    /// True while the edited profile's shortcuts diverge from
    /// the base — drives the "overrides base keybindings"
    /// indicator (#55 phase 7).
    var editedProfileOverridesKeys: Bool {
        guard let base = profileEditingBaseModes else {
            return false
        }
        return KeyModeOverride.diff(
            base: base,
            edited: config.modes
        ) != nil
    }
}
