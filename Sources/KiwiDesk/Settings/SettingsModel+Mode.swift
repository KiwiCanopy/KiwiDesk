import Foundation

/// The mode pick's model half and the draft-state recompute
/// (#678 turn 9) — split from `SettingsModel.swift` for the
/// §2.1 size target.
extension SettingsModel {
    /// The one recompute for the dirty flag AND the header's
    /// per-setting count — a live comparison against the
    /// baselines, never a latch, so the two cannot disagree.
    func recomputeDirty() {
        isDirty =
            config != cleanConfig
            || luaSource != cleanLuaSource
        draftChangeCount =
            isDirty
            ? SettingsDraftDiff.between(
                config: config,
                cleanConfig: cleanConfig,
                luaSource: luaSource,
                cleanLuaSource: cleanLuaSource
            ).total
            : 0
    }

    /// Persists the pick and repairs the selection: a Power-User-only
    /// area the flip just removed pops to Home (the area ceased
    /// to exist — mode gates whole cards, so this is the
    /// settled "which cards exist" rule, not a grey-don't-hide
    /// case).
    func setSettingsMode(_ mode: SettingsMode) {
        SettingsModePreference.write(
            mode,
            to: settingsModeDefaults
        )
        settingsMode = mode
        if let current = destination,
            !HomeCardOrder.isOffered(
                current,
                mode: mode,
                displayCount: displays.count,
                editingStoredProfile: editingStoredProfile
            )
        {
            destination = nil
        }
    }
}
