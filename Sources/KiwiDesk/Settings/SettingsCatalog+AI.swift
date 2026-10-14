import KiwiDeskCore

/// AI page declarations (#1685): three cards and one control per
/// census row, keyed on the row's label key (#1250).
struct AIControls: Sendable {
    let setupCard = SettingsControl("ai.setup.title", "Set up")
    let copySetupPrompt = SettingsControl(
        "ai.setup.copy",
        "Copy Setup Prompt"
    )
    let capabilitiesCard = SettingsControl(
        "ai.capabilities.title",
        "What it can do"
    )
    let promptsCard = SettingsControl(
        "ai.prompts.title",
        "Ready-made prompts"
    )
    let promptLook = SettingsControl(
        "ai.prompt.look",
        "Make a new look"
    )
    let promptSpaces = SettingsControl(
        "ai.prompt.spaces",
        "Set up my Spaces"
    )
}
