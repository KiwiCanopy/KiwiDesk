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
        // The first three used to name LAYOUT MODES in prose
        // ("IDE stack", "scrolling docs", "a deep-work monocle
        // Space") and ten catalogs then translated those words
        // inconsistently — `de` shipped "IDE-Stapel" and
        // "scrollende Dokumentation" beside a picker reading
        // "Stack" and "Scrolling", while keeping "Monocle" in the
        // next key along. No content guard can see it:
        // `untranslated_mode_names` fires on the OPPOSITE polarity
        // (a translated picker with English prose), and `de` has
        // English pickers with translated prose.
        //
        // Two words moved again after the round's separate audit
        // (2026-08-17), both by the SAME rule that refused
        // "Preview" for the button — Family C rule 1, a word
        // already naming another KiwiDesk concept loses. "a
        // fullscreen preview Space" spent the detail panel's word
        // (`panel.*_preview`, four keys) on the card whose button
        // is deliberately not called Preview; "dashboards" spent
        // the one `discard.*` uses for KiwiDesk's own Settings
        // dashboard. Both were faithfully carried into most
        // catalogs, so the reuse was ten-fold rather than one.
        //
        // So the card stops naming layouts at all (#859). A
        // summary says what you DO on those Spaces; the layouts
        // are named where they are drawn — the preview sheet's
        // tiles, through `LayoutMode.displayName`, which every
        // catalog already renders under a policy
        // `LocalizationModeNamePolicyTests` pins. Re-authoring
        // rather than guarding removes the class instead of
        // watching it.
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
        // "main screen", not "main display": these two lines draw
        // DIRECTLY above `PresetScreenCard`'s outlines, whose own
        // label says "Main screen" (#789's `presets.screen_name.*`
        // pair), so the card named one screen two ways. Fixed
        // here because #859 re-authors this family anyway — the
        // repo-wide screen/display/monitor split is a separate
        // owner ruling plus a catalog-wide sweep, and it is
        // deliberately NOT in this change set.
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
                "Spaces chosen for your screens, each with its "
                    + "own layout."
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
    // The WORKFLOW list, not the live catalog. A display name is
    // keyed on the stable English `name`, and `displayName` has
    // no Starter case — so the Starter entry resolved through
    // `default: return name`, byte-identical to the fallback
    // below, after three allocations and a tuning build ran to
    // produce it (architect review, 2026-08-11).
    StandardProfiles.workflows.first { $0.name == name }?
        .displayName ?? name
}

/// A positional screen's name: 0 is the main display and the rest
/// are numbered (#789).
///
/// The preset card denotes "main" by POSITION — leftmost — which
/// is a claim a reader who cannot see the row has no way to
/// recover: every screen announced itself as "Screen N" and
/// nothing said which one the Mac treats as main. The
/// alternatives were both refused by the consult that ruled this:
/// a heavier stroke, because `SettingsTheme+Metrics` records that
/// weight alone on a hairline was invisible on device and because
/// stroke weight already carries two meanings in this window; and
/// a micro-label, which at that outline size is ~7 pt type.
/// Saying it in words costs no pixels and removes the inference
/// rather than decorating it.
///
/// A NAME rather than a branched sentence, so the frames that
/// interpolate it stay one frame each and a locale reorders them
/// freely. It feeds `PresetScreenCard`'s two help frames and the
/// preview sheet's screen headings (#859) — **authored once here**
/// rather than at each call site, because a pair of keys feeding
/// one specifier slot is one naming decision and duplicating the
/// `L()` calls is how the two arms come to disagree.
///
/// **Both arms say "screen", and that is load-bearing.** They are
/// two alternatives for ONE specifier slot, so a pair reading
/// "Main display" / "Screen %1$d" puts two nouns for one concept
/// in one slot and makes every catalog reconcile it alone — which
/// all ten duly did, each picking a different side, while English
/// was the only catalog whose own pair disagreed (translation
/// audit, 2026-08-16). The noun is "screen" because this card's
/// neighbours are: the group heading counts screens
/// (`presets.for_your.*`), as do `presets.needs_screens`,
/// `presets.none_for_count`, `presets.starter.summary`,
/// `profiles.screens.*` — and, since #859, the two preset
/// summaries that used to read "on the main display"
/// (`presets.dual_developer.summary`,
/// `presets.coder_and_monitor.summary`).
///
/// This does NOT settle screen vs display vs monitor for the repo
/// — `config-vocabulary.md`'s glossary and
/// `docs/localization-naming.md` are both silent on it while
/// `en.json` uses all three, which is an owner ruling and a
/// catalog-wide sweep. It settles the Presets surface.
@MainActor func presetScreenName(_ screen: Int) -> String {
    screen == 0
        ? L("presets.screen_name.main", "Main screen")
        : L(
            "presets.screen_name.numbered",
            "Screen %1$d",
            screen + 1
        )
}
