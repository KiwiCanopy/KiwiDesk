import KiwiDeskCore

/// KiwiVision page declarations (#2103): two cards and one
/// control per census row, keyed on the row's label key (#1250).
struct KiwiVisionControls: Sendable {
    let levelsCard = SettingsControl(
        "kiwivision.section.levels",
        "Dim and blur"
    )
    let dim = SettingsControl("kiwivision.dim", "Dim")
    let blur = SettingsControl("kiwivision.blur", "Blur")
    let appearanceCard = SettingsControl(
        "kiwivision.section.appearance",
        "System appearance"
    )
    let appearance = SettingsControl(
        "kiwivision.appearance",
        "Appearance while on"
    )
}
