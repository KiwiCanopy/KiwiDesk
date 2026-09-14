/// Mac Checklist rows (#1365): the macOS settings a tiler fights,
/// read live and never written, and the habits that have no
/// setting. A row is a `(readonly)` census entry so search
/// reaches it; the one stored value is the fallback self-tick
/// set for a row macOS would not answer.

enum MacChecklistKey: String, CaseIterable, Hashable {
    case rearrangeSpaces = "(readonly) mac_checklist.rearrange_spaces"
    case switchOnActivate =
        "(readonly) mac_checklist.switch_on_activate"
    case stageManager = "(readonly) mac_checklist.stage_manager"
    case edgeTiling = "(readonly) mac_checklist.edge_tiling"
    case clickWallpaper = "(readonly) mac_checklist.click_wallpaper"
    case doubleClickTitle =
        "(readonly) mac_checklist.double_click_title"
    case habitHide = "(readonly) mac_checklist.habit.hide"
    case habitBigWindows = "(readonly) mac_checklist.habit.big_windows"
    case habitKeyboard = "(readonly) mac_checklist.habit.keyboard"
    case habitFloat = "(readonly) mac_checklist.habit.float"
    case habitDock = "(readonly) mac_checklist.habit.dock"
    case selfTicks = "UserDefaults.mac_checklist.ticks"
}

extension MacChecklistKey {
    var placement: SettingPlacement {
        switch self {
        case .rearrangeSpaces, .switchOnActivate, .stageManager,
            .edgeTiling:
            return .row(.macChecklist, .essentialSettings, .atRest)
        case .clickWallpaper, .doubleClickTitle:
            return .row(.macChecklist, .optionalSettings, .atRest)
        case .habitHide, .habitBigWindows, .habitKeyboard,
            .habitFloat, .habitDock:
            return .row(.macChecklist, .habits, .atRest)
        case .selfTicks:
            return .internalOnly
        }
    }

    var text: SettingRowText {
        switch self {
        case .selfTicks:
            return .none
        case .rearrangeSpaces, .switchOnActivate, .stageManager,
            .edgeTiling, .clickWallpaper, .doubleClickTitle,
            .habitHide, .habitBigWindows, .habitKeyboard,
            .habitFloat, .habitDock:
            return .text(labelKey, caption: labelKey + ".caption")
        }
    }

    /// The `L()` key of the row's title; the caption is that key
    /// plus `.caption` (`MacChecklistText` authors both).
    var labelKey: String {
        String(rawValue.dropFirst("(readonly) ".count))
    }
}
