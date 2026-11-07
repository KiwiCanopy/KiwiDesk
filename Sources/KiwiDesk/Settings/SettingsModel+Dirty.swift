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

    /// The draft against its baseline, walked once per write to
    /// either: the save pill's rows and the dirty count both read it
    /// on every render (#3060, `DraftDiffCacheTests`).
    var draftDiff: SettingsDraftDiff {
        if let value = draftMemo.value { return value }
        let value = SettingsDraftDiff.between(
            config: config,
            cleanConfig: cleanConfig,
            luaSource: luaSource,
            cleanLuaSource: cleanLuaSource
        )
        draftMemo.value = value
        return value
    }
}

/// The last draft diff, dropped by every write to the four inputs it
/// walks: `config`, `cleanConfig`, `luaSource`, `cleanLuaSource`.
/// Keyed on the writes, never the values: `GuiConfig ==` skips
/// fields the walk reads (a binding's id, a Desktop entry's name).
struct DraftDiffMemo {
    var value: SettingsDraftDiff?
    /// How many writes it has seen, which a test reads.
    private(set) var writes = 0

    mutating func bump() {
        writes += 1
        value = nil
    }
}
