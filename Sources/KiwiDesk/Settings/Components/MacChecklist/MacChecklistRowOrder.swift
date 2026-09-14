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

    /// Where a habit's sentence links at its slot: a KiwiDesk
    /// surface, or System Settings for the Dock habit, which
    /// names a macOS switch the way the settings rows do; nil for
    /// a habit naming neither.
    var link: MacChecklistLink? {
        switch self {
        case .habitBigWindows: return .destination(.spaces)
        case .habitKeyboard: return .destination(.shortcuts)
        case .habitFloat: return .destination(.appRules)
        case .habitDock: return .systemSettings
        case .habitHide, .rearrangeSpaces,
            .switchOnActivate, .stageManager, .edgeTiling,
            .clickWallpaper, .doubleClickTitle, .selfTicks:
            return nil
        }
    }

}

/// What a habit's link slot opens.
enum MacChecklistLink: Hashable {
    case destination(SettingsDestination)
    case systemSettings
}

/// The ONE home of the count (#1365): essentials only, derived
/// from the order list so the N beside a visible list is that
/// list's rows (`gui.md` ▸ Home). `verdicts` is the one value —
/// the card face draws it and `done` counts it — so the face
/// cannot show a row the count does not. A row is done when
/// macOS answers `.set`, or when it would not answer and the
/// user ticked it themselves.
enum MacChecklistProgress {
    static let essentials: [MacSetting] =
        MacChecklistRowOrder.essentialSettings.compactMap {
            guard case .macChecklist(let key) = $0 else {
                return nil
            }
            return key.setting
        }

    static var total: Int { essentials.count }

    /// The one reading of an unread row: not set.
    static func state(
        of setting: MacSetting,
        in states: [MacSetting: MacSettingState]
    ) -> MacSettingState {
        states[setting] ?? .notSet
    }

    @MainActor static func state(
        of setting: MacSetting,
        in model: SettingsModel
    ) -> MacSettingState {
        state(of: setting, in: model.macChecklistStates)
    }

    static func isDone(
        _ setting: MacSetting,
        states: [MacSetting: MacSettingState],
        ticks: Set<MacSetting>
    ) -> Bool {
        switch state(of: setting, in: states) {
        case .set: return true
        case .unreadable: return ticks.contains(setting)
        case .notSet: return false
        }
    }

    /// Every essential with its verdict, in order.
    static func verdicts(
        states: [MacSetting: MacSettingState],
        ticks: Set<MacSetting>
    ) -> [(setting: MacSetting, done: Bool)] {
        essentials.map {
            ($0, isDone($0, states: states, ticks: ticks))
        }
    }

    static func done(
        states: [MacSetting: MacSettingState],
        ticks: Set<MacSetting>
    ) -> Int {
        verdicts(states: states, ticks: ticks).filter(\.done).count
    }
}
