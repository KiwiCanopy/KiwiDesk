import KiwiDeskCore

/// Mac Checklist row order (`MacChecklistCensusRenderTests`,
/// #1365). Rank is ORDER — the essentials run from the setting
/// that breaks the most to the one that costs least — so a
/// re-ranking is a census edit and nothing on screen restates
/// it. Every container is a real `ForEach` over its list.
enum MacChecklistRowOrder {
    static let essentialSettings: [SettingKey] = [
        .macChecklist(.rearrangeSpaces),
        .macChecklist(.switchOnActivate),
        .macChecklist(.stageManager),
        .macChecklist(.edgeTiling),
    ]

    static let optionalSettings: [SettingKey] = [
        .macChecklist(.clickWallpaper),
        .macChecklist(.doubleClickTitle),
    ]

    static let habits: [SettingKey] = [
        .macChecklist(.habitHide),
        .macChecklist(.habitBigWindows),
        .macChecklist(.habitKeyboard),
        .macChecklist(.habitFloat),
        .macChecklist(.habitDock),
    ]

    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .essentialSettings: essentialSettings,
        .optionalSettings: optionalSettings,
        .habits: habits,
    ]

    /// None: every container iterates its list (`gui.md`).
    static let bespokeContainers: Set<SettingsContainer> = []
}

extension MacChecklistKey {
    /// The macOS setting a settings row reads; nil for a habit
    /// and the tick store.
    var setting: MacSetting? {
        switch self {
        case .rearrangeSpaces: return .rearrangeSpaces
        case .switchOnActivate: return .switchOnActivate
        case .stageManager: return .stageManager
        case .edgeTiling: return .edgeTiling
        case .clickWallpaper: return .clickWallpaper
        case .doubleClickTitle: return .doubleClickTitle
        case .habitHide, .habitBigWindows, .habitKeyboard,
            .habitFloat, .habitDock, .selfTicks:
            return nil
        }
    }

    /// Where a habit's sentence links; nil for one that names no
    /// KiwiDesk surface.
    var destination: SettingsDestination? {
        switch self {
        case .habitBigWindows: return .spaces
        case .habitKeyboard: return .shortcuts
        case .habitFloat: return .appRules
        case .habitHide, .habitDock, .rearrangeSpaces,
            .switchOnActivate, .stageManager, .edgeTiling,
            .clickWallpaper, .doubleClickTitle, .selfTicks:
            return nil
        }
    }
}

/// The ONE count (#1365): essentials only, read by the Home card
/// and the section header alike, derived from the order list so
/// the N beside a visible list is that list's rows (`gui.md` ▸
/// Home). A row is done when macOS answers `.set`, or when it
/// would not answer and the user ticked it themselves.
enum MacChecklistProgress {
    static let essentials: [MacSetting] =
        MacChecklistRowOrder.essentialSettings.compactMap {
            guard case .macChecklist(let key) = $0 else {
                return nil
            }
            return key.setting
        }

    static var total: Int { essentials.count }

    static func isDone(
        _ setting: MacSetting,
        states: [MacSetting: MacSettingState],
        ticks: Set<MacSetting>
    ) -> Bool {
        switch states[setting] {
        case .set: return true
        case .unreadable: return ticks.contains(setting)
        case .notSet, nil: return false
        }
    }

    static func done(
        states: [MacSetting: MacSettingState],
        ticks: Set<MacSetting>
    ) -> Int {
        essentials.filter {
            isDone($0, states: states, ticks: ticks)
        }.count
    }
}
