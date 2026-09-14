import Foundation

/// The Mac Checklist's model half (#1365): one live read of every
/// row, refreshed on appear and on the app coming forward — the
/// `LoginItemCard` shape, so the user flips a switch in System
/// Settings, comes back, and the row updates — plus the fallback
/// self-tick store for a row macOS would not answer.
extension SettingsModel {
    /// `UserDefaults.mac_checklist.ticks` (`MacChecklistKey`).
    static let macChecklistTicksKey = "mac_checklist.ticks"

    func refreshMacChecklist() {
        var states: [MacSetting: MacSettingState] = [:]
        for setting in MacSetting.allCases {
            states[setting] = MacSettingRead.state(
                of: setting,
                reading: readMacSetting(setting)
            )
        }
        guard states != macChecklistStates else { return }
        macChecklistStates = states
    }

    /// Rows the user ticked because macOS would not answer.
    var macChecklistTicks: Set<MacSetting> {
        Set(
            (preferences.stringArray(
                forKey: Self.macChecklistTicksKey
            ) ?? [])
            .compactMap(MacSetting.init(rawValue:))
        )
    }

    func setMacChecklistTick(_ setting: MacSetting, _ on: Bool) {
        var ticks = macChecklistTicks
        if on { ticks.insert(setting) } else { ticks.remove(setting) }
        preferences.set(
            ticks.map(\.rawValue).sorted(),
            forKey: Self.macChecklistTicksKey
        )
        objectWillChange.send()
    }

    /// Essentials done, the one count both surfaces read.
    var macChecklistDone: Int {
        MacChecklistProgress.done(
            states: macChecklistStates,
            ticks: macChecklistTicks
        )
    }
}
