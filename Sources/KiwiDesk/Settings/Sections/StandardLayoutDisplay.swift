import KiwiDeskCore

/// Localized display text for the shipped Standard/Preset
/// layouts (#53). `StandardLayout.name` stays the stable,
/// English canonical identity — it seeds a new saved profile's
/// name (`freeName(base: layout.name)`,
/// `KiwiCore+ProfileResolution.swift`) and labels
/// `activeStandard`/`Composed.sourceName`, both of which persist
/// or drive further lookups. Only the GUI rendering translates;
/// resolution is keyed by `name` so a language switch never
/// touches the underlying identity. Mirrors `LayoutMode.
/// displayName` (`LayoutModeGlyph.swift`).
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

    @MainActor var displaySummary: String {
        switch name {
        case "Developer":
            return L(
                "presets.developer.summary",
                "IDE stack, scrolling docs, and a fullscreen "
                    + "preview space."
            )
        case "Minimalist":
            return L(
                "presets.minimalist.summary",
                "Spacious gaps, a scrolling reading space, "
                    + "and single-focus work."
            )
        case "Focus Stack":
            return L(
                "presets.focus_stack.summary",
                "Two stacked task spaces and a deep-work "
                    + "monocle space."
            )
        case "Dual Developer":
            return L(
                "presets.dual_developer.summary",
                "Code and docs on the main display; mail, "
                    + "chat, and media on the second."
            )
        case "Coder & Monitor":
            return L(
                "presets.coder_and_monitor.summary",
                "Editor and terminals on the main display; "
                    + "dashboards and logs on the second."
            )
        case "Command Center":
            return L(
                "presets.command_center.summary",
                "Workspace and docs center, communication "
                    + "left, logs and monitoring right."
            )
        case "Visual Creative & Developer":
            return L(
                "presets.visual_creative.summary",
                "Frontend IDE and previews center, design "
                    + "canvas left, inspectors right."
            )
        default:
            return summary
        }
    }
}

/// Resolves a Standard's stable English `name` (e.g.
/// `activeStandard`, `Composed.sourceName`) to its localized
/// display text — used wherever the name arrives as a bare
/// `String` rather than a `StandardLayout`, so `ProfileHeader`
/// shows the same translated name as the Presets list.
@MainActor func standardDisplayName(_ name: String) -> String {
    StandardProfiles.all.first { $0.name == name }?
        .displayName ?? name
}
