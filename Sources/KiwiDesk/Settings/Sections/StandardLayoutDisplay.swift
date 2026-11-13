import KiwiDeskCore

/// Localized display text for shipped Standard/Preset layouts (#53, #859).
/// Resolution is keyed by canonical English `name`.
extension StandardLayout {
    @MainActor var displayName: String {
        if let starterTitle { return starterTitle.displayName }
        switch name {
        case "Developer":
            return L("presets.developer.name", "Developer")
        case "Focus":
            return L("presets.focus.name", "Focus")
        case "Studio":
            return L("presets.studio.name", "Studio")
        case "Dashboard":
            return L("presets.dashboard.name", "Dashboard")
        default:
            return name
        }
    }
}

/// Resolves standard profile English name to localized display
/// string; the starter answers with its `title` (#1662), never its
/// identity.
@MainActor func standardDisplayName(
    _ name: String,
    title: StarterTitle?
) -> String {
    if name == StarterSetup.name, let title { return title.displayName }
    return StandardProfiles.workflows.first { $0.name == name }?
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
