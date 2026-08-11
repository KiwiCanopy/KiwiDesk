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
        // The Starter setup, which leads its own screen count in
        // the Presets list. It used to fall through to a
        // `summary` string built in Core, so the first preset a
        // new user sees rendered raw English in every locale
        // (#601).
        //
        // ONE key, where the ladder had three. The ladder planned
        // for a screen COUNT, so its copy could name the modes it
        // would lay down; this setup derives them from the shapes
        // of the screens actually connected, and a sentence
        // listing them would be a different sentence on every
        // Mac. What stays true everywhere is the rule, so that is
        // what the summary states — the modes themselves are on
        // the thumbnails beside it (#678 Phase 4 pass 11).
        case StarterSetup.name:
            return L(
                "presets.starter.summary",
                "Spaces chosen for the screens you have, each "
                    + "with the layout that screen suits."
            )
        default:
            // Unreachable for anything in `StandardProfiles.all`,
            // and `PresetSummaryCoverageTests` proves it. Core no
            // longer carries copy to fall back to, so a preset
            // without a case here renders blank rather than
            // untranslated English — the right trade (a missing
            // caption beats an unlocalized one), but a silent
            // one. Shout in debug so the mistake surfaces where
            // it is made, while release still never shows
            // English.
            assertionFailure(
                "preset '\(name)' (\(screenCount) screen) has "
                    + "no localized summary"
            )
            return ""
        }
    }
}

/// Resolves a Standard's stable English `name` (e.g.
/// `activeStandard`, `Composed.sourceName`) to its localized
/// display text — used wherever the name arrives as a bare
/// `String` rather than a `StandardLayout`, so `ProfileHeader`
/// shows the same translated name as the Presets list.
@MainActor func standardDisplayName(_ name: String) -> String {
    // Empty sizes deliberately: a layout's display NAME is keyed
    // on its stable English `name` alone, so the Starter entry's
    // screens do not enter into it and asking for them here would
    // thread live hardware through a pure string lookup.
    StandardProfiles.all(sizes: []).first { $0.name == name }?
        .displayName ?? name
}
