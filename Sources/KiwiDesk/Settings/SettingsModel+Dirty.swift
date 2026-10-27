import Foundation

/// Draft state diffing (`SettingsDraftDiff`, #678 turn 9).
extension SettingsModel {
    /// Recomputes dirty status and draft modification count
    /// (`SettingsDraftDiff`).
    func recomputeDirty() {
        // A checklist change may reach only OTHER profiles, which
        // the config comparison cannot see (#1393).
        let reachRows = reachDiffRows().count + lookReachDiffRows().count
        isDirty =
            config != cleanConfig
            || luaSource != cleanLuaSource
            || reachRows > 0
        draftChangeCount =
            isDirty
            ? SettingsDraftDiff.between(
                config: config,
                cleanConfig: cleanConfig,
                luaSource: luaSource,
                cleanLuaSource: cleanLuaSource
            ).total + reachRows
            : 0
    }

}
