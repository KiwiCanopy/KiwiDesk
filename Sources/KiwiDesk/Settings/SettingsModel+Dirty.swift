import Foundation
import KiwiDeskCore

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
            ? draftDiff.total + reachRows
            : 0
    }

    /// The draft against its baseline, walked once per change of
    /// either: the save pill's rows and the dirty count both read it
    /// on every render (#3060). `Key` lists every input
    /// `SettingsDraftDiff.between` reads (`DraftDiffCacheTests`).
    var draftDiff: SettingsDraftDiff {
        let key = DraftDiffCache.Key(
            config: config,
            cleanConfig: cleanConfig,
            luaSource: luaSource,
            cleanLuaSource: cleanLuaSource
        )
        if let cache = draftDiffCache, cache.key == key { return cache.value }
        let value = SettingsDraftDiff.between(
            config: key.config,
            cleanConfig: key.cleanConfig,
            luaSource: key.luaSource,
            cleanLuaSource: key.cleanLuaSource
        )
        draftDiffCache = DraftDiffCache(key: key, value: value)
        return value
    }
}

/// The last draft diff and the four inputs it read.
struct DraftDiffCache {
    struct Key: Equatable {
        let config: GuiConfig
        let cleanConfig: GuiConfig
        let luaSource: String
        let cleanLuaSource: String
    }

    let key: Key
    let value: SettingsDraftDiff
}
