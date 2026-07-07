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

    /// Save copy as… (#82): duplicates the edited stored
    /// profile under `requested` — including the pending
    /// edit-session changes — and makes the copy the new edit
    /// target. Non-adopting: the live layout, `gui.json`, and
    /// `init.lua` stay untouched.
    func saveEditedProfileCopy(named requested: String) {
        guard let source = editingProfile else { return }
        let trimmed = requested.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return }
        do {
            let created = try core.copyProfile(
                named: source,
                to: trimmed,
                with: config
            )
            // `freeName` only returns names absent from
            // `profiles.list()`, and `activeProfile` is always
            // a listed name while it exists — so `created` can
            // never equal `activeProfile`, and the direct
            // assignment safely skips `selectEditTarget`'s
            // this-is-live-editing normalization.
            editingProfile = created
            reload()
        } catch {
            profileWarning = "Copying failed: \(error)"
            core.onLog("profile copy failed: \(error)")
        }
    }

    /// Writes the edited tiling into the stored profile without
    /// switching the live layout, then hot-reloads it only if it
    /// is the layout currently on screen (#18).
    func saveEditedProfile() {
        guard let name = editingProfile else { return }
        do {
            try core.overwriteProfile(named: name, with: config)
        } catch {
            profileWarning = "Saving failed: \(error)"
            core.onLog("profile edit save failed: \(error)")
            return
        }
        core.reapplyIfInEffect(name)
        reload()
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
