import KiwiDeskCore

/// Localized display text for shipped Standard/Preset layouts (#53, #859).
/// Resolution is keyed by canonical English `name`.
extension StandardLayout {
    @MainActor var displayName: String {
        switch name {
        case "Developer":
            return L("presets.developer.name", "Developer")
        case "Minimalist":
            return L("presets.minimalist.name", "Minimalist")
        case "Focus Stack":
            return L("presets.focus_stack.name", "Focus Stack")
        case "Dual Developer":
            return L(
                "presets.dual_developer.name",
                "Dual Developer"
            )
        case "Coder & Monitor":
            return L(
                "presets.coder_and_monitor.name",
                "Coder & Monitor"
            )
        case "Command Center":
            return L(
                "presets.command_center.name",
                "Command Center"
            )
        case "Visual Creative & Developer":
            return L(
                "presets.visual_creative.name",
                "Visual Creative & Developer"
            )
        default:
            return name
        }
    }

    /// Localized summary describing workflow across spaces (#859,
    /// `PresetSummaryCoverageTests`).
    @MainActor var displaySummary: String {
        switch name {
        case "Developer":
            return L(
                "presets.developer.summary",
                "An IDE, reference docs, and a full-screen "
                    + "Space for the running app."
            )
        case "Minimalist":
            return L(
                "presets.minimalist.summary",
                "Generous gaps, a Space for reading, and "
                    + "single-focus work."
            )
        case "Focus Stack":
            return L(
                "presets.focus_stack.summary",
                "Two task Spaces, and one kept clear for deep "
                    + "work."
            )
        case "Dual Developer":
            return L(
                "presets.dual_developer.summary",
                "Code and docs on the main screen; mail, "
                    + "chat, and media on the second."
            )
        case "Coder & Monitor":
            return L(
                "presets.coder_and_monitor.summary",
                "Editor and terminals on the main screen; "
                    + "metrics and logs on the second."
            )
        case "Command Center":
            return L(
                "presets.command_center.summary",
                "Work and docs center, communication "
                    + "left, logs and monitoring right."
            )
        case "Visual Creative & Developer":
            return L(
                "presets.visual_creative.summary",
                "Frontend IDE and previews center, design "
                    + "canvas left, inspectors right."
            )
        case StarterSetup.name:
            return L(
                "presets.starter.summary",
                "Spaces chosen for your screens, each with its "
                    + "own layout."
            )
        default:
            assertionFailure(
                "preset '\(name)' (\(screenCount) screen) has "
                    + "no localized summary"
            )
            return ""
        }
    }
}

/// Resolves standard profile English name to localized display string.
@MainActor func standardDisplayName(_ name: String) -> String {
    StandardProfiles.workflows.first { $0.name == name }?
        .displayName ?? name
}

/// Positional screen name: 0 is main screen, rest are numbered (#789, #859).
@MainActor func presetScreenName(_ screen: Int) -> String {
    screen == 0
        ? L("presets.screen_name.main", "Main screen")
        : L(
            "presets.screen_name.numbered",
            "Screen %1$d",
            screen + 1
        )
}
