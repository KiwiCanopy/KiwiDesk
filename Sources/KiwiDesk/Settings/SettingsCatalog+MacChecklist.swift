/// Mac Checklist declarations (#1365): three section cards and
/// one control per census row, keyed on the row's census label
/// key so the census hit resolves to the row (#1250). Titles
/// quote Apple's own labels verbatim — as macOS 26.6 renders
/// them (`DesktopSettings.appex`'s `Localizable.loctable`,
/// 2026-09-14), so a locale reaches for Apple's translation
/// (`config-vocabulary.md`).
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
        "Turn off \u{201C}Drag windows to left or right edge of "
            + "screen to tile\u{201D}"
    )
    let optionalCard = SettingsControl(
        "mac_checklist.optional.title",
        "Optional settings"
    )
    let clickWallpaper = SettingsControl(
        "mac_checklist.click_wallpaper",
        "Set \u{201C}Click wallpaper to show desktop\u{201D} to "
            + "\u{201C}Only in Stage Manager\u{201D}"
    )
    let doubleClickTitle = SettingsControl(
        "mac_checklist.double_click_title",
        "Set \u{201C}Window title bar double-click action\u{201D} "
            + "to \u{201C}None\u{201D}"
    )
    let habitsCard = SettingsControl(
        "mac_checklist.habits.title",
        "Habits"
    )
    let habitHide = SettingsControl(
        "mac_checklist.habit.hide",
        "Move it or close it — don\u{2019}t hide it"
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
    /// The app's one permanent guide pointer, declared so search
    /// reaches it (#1019, #1470, `SettingsSearchIndex`).
    let guideLink = SettingsControl(
        "mac_checklist.guide",
        "Guide"
    )
}
