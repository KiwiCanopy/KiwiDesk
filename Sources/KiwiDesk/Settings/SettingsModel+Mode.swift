import Foundation

/// The Simple/Power User pick's model half (#678 turn 9) — split from
/// `SettingsModel.swift` for the §2.1 size target.
extension SettingsModel {
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
