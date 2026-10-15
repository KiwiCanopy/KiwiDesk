import KiwiDeskCore

/// KiwiVision page declarations (#2103): four cards and one
/// control per census row, keyed on the row's label key (#1250).
struct KiwiVisionControls: Sendable {
    let levelsCard = SettingsControl(
        "kiwivision.section.levels",
        "Dim and blur"
    )
    let dim = SettingsControl("kiwivision.dim", "Dim")
    let blur = SettingsControl("kiwivision.blur", "Blur")
    let clearCard = SettingsControl(
        "kiwivision.section.clear",
        "Stays clear"
    )
    let clearApp = SettingsControl(
        "kiwivision.clear_app",
        "The current app's other windows"
    )
    let clearWallpaper = SettingsControl(
        "kiwivision.clear_wallpaper",
        "Wallpaper"
    )
    let neverDimmedCard = SettingsControl(
        "kiwivision.section.never_dimmed",
        "Never dimmed"
    )
    let neverDimmed = SettingsControl(
        "kiwivision.never_dimmed",
        "Never dimmed apps"
    )
    let appearanceCard = SettingsControl(
        "kiwivision.section.appearance",
        "System appearance"
    )
    let appearance = SettingsControl(
        "kiwivision.appearance",
        "Appearance while on"
    )
}
