import Foundation

/// Settings mode transitions and draft state diffing
/// (`SettingsDraftDiff`, #678 turn 9).
extension SettingsModel {
    /// Recomputes dirty status and draft modification count
    /// (`SettingsDraftDiff`).
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

    /// Persists settings mode selection and validates destination
    /// (`HomeCardOrder`).
    func setSettingsMode(_ mode: SettingsMode) {
        SettingsModePreference.write(
            mode,
            to: preferences
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

    /// Triggers user-driven mode switch and activates reveal wash
    /// (`SettingsReveal`, #760).
    func flipSettingsMode(
        _ mode: SettingsMode,
        reduceMotion: Bool
    ) {
        let reveals =
            mode == .powerUser && settingsMode != .powerUser
        if reveals {
            modeRevealTask?.cancel()
            modeRevealActive = true
        } else if mode != .powerUser {
            modeRevealTask?.cancel()
            modeRevealActive = false
        }
        setSettingsMode(mode)
        guard reveals else { return }
        modeRevealTask = Task { @MainActor [weak self] in
            try? await Task.sleep(
                nanoseconds: SettingsReveal.nanoseconds(
                    SettingsReveal.hold
                        + (reduceMotion ? SettingsReveal.fade : 0)
                )
            )
            guard !Task.isCancelled else { return }
            self?.modeRevealActive = false
        }
    }
}
