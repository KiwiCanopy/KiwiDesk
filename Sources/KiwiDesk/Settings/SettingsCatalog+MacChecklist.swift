/// Mac Checklist declarations (#1365): three section cards and
/// one control per census row, keyed on the row's census label
/// key so the census hit resolves to the row (#1250). Titles
/// quote Apple's own labels verbatim, so a locale reaches for
/// Apple's translation (`config-vocabulary.md`).
struct MacChecklistControls: Sendable {
    let essentialsCard = SettingsControl(
        "mac_checklist.essentials.title",
        "Essential settings"
    )
    let rearrangeSpaces = SettingsControl(
        "mac_checklist.rearrange_spaces",
        "Turn off \u{201C}Automatically rearrange Spaces based on "
            + "most recent use\u{201D}"
    )
    let switchOnActivate = SettingsControl(
        "mac_checklist.switch_on_activate",
        "Turn off \u{201C}When switching to an application, switch "
            + "to a Space with open windows for the application\u{201D}"
    )
    let stageManager = SettingsControl(
        "mac_checklist.stage_manager",
        "Turn off Stage Manager"
    )
    let edgeTiling = SettingsControl(
        "mac_checklist.edge_tiling",
        "Turn off \u{201C}Tile by dragging windows to screen "
            + "edges\u{201D}"
    )
    let optionalCard = SettingsControl(
        "mac_checklist.optional.title",
        "Optional settings"
    )
    let clickWallpaper = SettingsControl(
        "mac_checklist.click_wallpaper",
        "Set \u{201C}Click wallpaper to reveal desktop\u{201D} to "
            + "Only in Stage Manager"
    )
    let doubleClickTitle = SettingsControl(
        "mac_checklist.double_click_title",
        "Set \u{201C}Double-click a window\u{2019}s title bar to\u{201D} "
            + "to Do nothing"
    )
    let habitsCard = SettingsControl(
        "mac_checklist.habits.title",
        "Habits"
    )
    let habitHide = SettingsControl(
        "mac_checklist.habit.hide",
        "Move it or close it \u{2014} don\u{2019}t hide it"
    )
    let habitBigWindows = SettingsControl(
        "mac_checklist.habit.big_windows",
        "Big windows: Monocle or Scrolling"
    )
    let habitKeyboard = SettingsControl(
        "mac_checklist.habit.keyboard",
        "Keyboard first"
    )
    let habitFloat = SettingsControl(
        "mac_checklist.habit.float",
        "Float what should float"
    )
    let habitDock = SettingsControl(
        "mac_checklist.habit.dock",
        "Let the Dock hide"
    )
}
