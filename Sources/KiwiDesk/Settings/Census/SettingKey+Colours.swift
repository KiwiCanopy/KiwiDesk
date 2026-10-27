/// Animations (`AnimationSettings`) and palette actions.

enum ColoursKey: String, CaseIterable, Hashable {
    case liquidGlassMaster =
        "settings.kiwishelf.liquidGlass (master)"
    case shortcutPanelLiquidGlass =
        "settings.shortcutPanelLiquidGlass"
    case dragLiquidGlass = "settings.dragLiquidGlass"
    case stickyLiquidGlass = "settings.stickyStyle.liquidGlass"
    case borderSheen = "settings.borderStyle.sheen"
    case animationsMaster = "settings.animations (master)"
    /// App-wide (#1741), not an `AnimationSettings` field: how a
    /// Space switch shows itself and the slide's pace (#2524).
    case spaceTransition = "appWide.spaceTransition"
    case spaceSlideDuration = "appWide.spaceSlideDuration"
    case animationsOnWindowResize = "settings.animations.onWindowResize"
    case animationsOnWindowSwap = "settings.animations.onWindowSwap"
    case animationsOnRelayout = "settings.animations.onRelayout"
    case animationsOnStateChange = "settings.animations.onStateChange"
    case animationsDurationMS = "settings.animations.durationMS"
    case animationsOnScrolling = "settings.animations.onScrolling"
    case animationsScrollDurationMS =
        "settings.animations.scrollDurationMS"
    case animationsOnExpand = "settings.animations.onExpand"
    case animationsOnPeek = "settings.animations.onPeek"
    case animationsExpandDurationMS =
        "settings.animations.expandDurationMS"
    case animationsRevealDurationMS =
        "settings.animations.revealDurationMS"
    case paletteApply = "(action) palette.apply"
    case paletteSave = "(action) palette.save"
    case paletteRename = "(action) palette.rename"
    case paletteExport = "(action) palette.export"
    case paletteDelete = "(action) palette.delete"
    case paletteImport = "(action) palette.import"
    case paletteNeonGlowHint = "(link) palettes.neon_glow_hint"
    case lookApply = "(action) look.apply"
    case lookKeepPreviousColors = "(action) look.keep_previous_colors"
    /// Which profiles follow the shared look (#1752).
    case lookAppliesTo = "(action) look.applies_to"
    case lookSave = "(action) look.save"
    case lookImport = "(action) look.import"
    case lookRename = "(action) look.rename"
    case lookExport = "(action) look.export"
    case lookDelete = "(action) look.delete"
    /// Each role group's colour, written onto its ticked rows
    /// (#1857); it stores nothing of its own.
    case accentPaint = "(action) colors.accent.paint"
    case secondAccentPaint = "(action) colors.second_accent.paint"
}

extension ColoursKey {
    var placement: SettingPlacement {
        switch self {
        case .liquidGlassMaster:
            return .row(
                .coloursAndMotion,
                .glass,
                .atRest,
                gate: .runtime(.liquidGlassUnavailable)
            )
        case .shortcutPanelLiquidGlass, .dragLiquidGlass,
            .stickyLiquidGlass:
            // Written by the master row, never its own row —
            // and reachable from Lua like the shelf's leaf.
            return .luaOnly
        case .borderSheen:
            // Its own row beneath the master, never greyed and
            // never hidden: the sheen is not glass, so it draws
            // below macOS 26 too (#1644, owner 2026-09-27).
            return .row(
                .coloursAndMotion,
                .glass,
                .atRest,
                exemptFromContainerGate: true
            )
        case .animationsMaster:
            return .row(.coloursAndMotion, .motion, .atRest)
        case .spaceTransition, .spaceSlideDuration:
            // Above the master, which does not reach them, and
            // outside Reduce Motion's grey: the slide falls back to
            // Show the Space there (#2524). App-wide (#1741), so
            // they grey where init.lua owns the config, as the
            // Desktop cue does (#2142). The duration's grey while
            // the picker is off Slide is wiring's (gui.md).
            return .row(
                .coloursAndMotion,
                .motion,
                .atRest,
                gate: .runtime(.luaOwnsConfig),
                exemptFromContainerGate: true
            )
        case .animationsOnWindowResize,
            .animationsOnWindowSwap, .animationsOnRelayout,
            .animationsOnStateChange, .animationsDurationMS:
            return .row(
                .coloursAndMotion,
                .motion,
                .showMore,
                gate: .setting(.colours(.animationsMaster))
            )
        case .animationsOnExpand:
            // A hidden knob: its duration row says when it is off
            // (owner ruling, 2026-10-21).
            return .luaOnly
        case .animationsOnPeek:
            // The peeks' motion off, Lua-only (#2563).
            return .luaOnly
        case .animationsRevealDurationMS:
            // KiwiShelf ▸ Show ▸ Durations, greyed with the Reveal
            // row while no bar hides (owner ruling, 2026-10-21).
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: .runtime(.noBarHides)
            )
        case .animationsExpandDurationMS:
            // The expand plays with every bar on Always, so it greys
            // only while its hidden switch is off (2026-10-21).
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: .runtime(.expandOffInConfig)
            )
        case .animationsOnScrolling:
            return .row(.layoutDefaults, .scrolling, .atRest)
        case .animationsScrollDurationMS:
            return .row(
                .layoutDefaults,
                .scrolling,
                .atRest,
                gate: .setting(.colours(.animationsOnScrolling))
            )
        case .paletteApply, .paletteSave, .paletteImport:
            return .row(.coloursAndMotion, .palettes, .atRest)
        case .paletteRename, .paletteExport, .paletteDelete:
            // Context menu actions pinned by ColorsCensusRenderTests.
            return .row(.coloursAndMotion, .palettes, .showMore)
        case .lookApply, .lookSave, .lookImport:
            return .row(.coloursAndMotion, .looks, .atRest)
        case .lookKeepPreviousColors:
            // Present only while a look click replaced colours no
            // saved palette brings back (`KeepColorsOffer`).
            return .row(
                .coloursAndMotion,
                .looks,
                .atRest,
                gate: .runtime(.lookReplacedUnsavedColors)
            )
        case .lookRename, .lookExport, .lookDelete:
            return .row(.coloursAndMotion, .looks, .showMore)
        case .lookAppliesTo:
            return .row(.coloursAndMotion, .sharedLook, .atRest)
        case .accentPaint:
            // Its grey reads the card's own ticks — editor state the
            // saved config cannot answer, so a wiring predicate and
            // no census gate (gui.md); the reason is drawn beside it.
            return .row(.coloursAndMotion, .accent, .showMore)
        case .secondAccentPaint:
            return .row(.coloursAndMotion, .secondAccent, .showMore)
        case .paletteNeonGlowHint:
            return .row(
                .coloursAndMotion,
                .palettes,
                .atRest,
                gate: .runtime(.paletteGlowPairing)
            )
        }
    }
}

extension ColoursKey {
    var text: SettingRowText {
        switch self {
        case .shortcutPanelLiquidGlass, .dragLiquidGlass,
            .stickyLiquidGlass:
            return .none
        case .borderSheen:
            return .text("colors.sheen", caption: "colors.sheen.caption")
        case .liquidGlassMaster:
            return .text(
                "colors.liquid_glass",
                help: "colors.liquid_glass.help"
            )
        case .animationsMaster:
            return .text(
                "behavior.animations.master",
                help: "behavior.animations.master.help"
            )
        case .spaceTransition:
            return .text("animations.space_transition")
        case .spaceSlideDuration:
            return .text(
                "animations.space_slide_duration",
                help: "animations.space_slide_duration.help"
            )
        case .animationsOnWindowResize:
            return .text("behavior.animations.window_resize")
        case .animationsOnWindowSwap:
            return .text("behavior.animations.window_swap")
        case .animationsOnRelayout:
            return .text("behavior.animations.relayout")
        case .animationsOnStateChange:
            return .text(
                "behavior.animations.state_change",
                help: "behavior.animations.state_change.help"
            )
        case .animationsDurationMS:
            return .text(
                "behavior.animations.window_duration",
                help: "behavior.animations.window_duration.help"
            )
        case .animationsOnExpand, .animationsOnPeek:
            return .none
        case .animationsRevealDurationMS:
            return .text(
                "kiwishelf.reveal_duration",
                help: "kiwishelf.reveal_duration.help"
            )
        case .animationsExpandDurationMS:
            return .text(
                "kiwishelf.expand_duration",
                help: "kiwishelf.expand_duration.help"
            )
        case .animationsOnScrolling:
            return .text(
                "scroll_grid.animate_focus_shifts",
                help: "scroll_grid.animate_focus_shifts.help"
            )
        case .animationsScrollDurationMS:
            return .text("scroll_grid.scroll_duration")
        case .paletteApply:
            return .dynamic
        case .paletteSave:
            return .text("palettes.save_current")
        case .paletteRename:
            return .text("palettes.rename")
        case .paletteExport:
            return .text("palettes.export")
        case .paletteDelete:
            return .text("palettes.delete")
        case .paletteImport:
            return .text("palettes.import")
        case .paletteNeonGlowHint:
            return .text("palettes.neon_glow_hint")
        case .lookApply:
            return .dynamic
        case .lookKeepPreviousColors:
            return .text("looks.keep_previous_colors")
        case .lookAppliesTo:
            return .text("app_rules.reach")
        case .lookSave:
            return .text("looks.save_current")
        case .lookImport:
            return .text("looks.import")
        case .lookRename:
            return .text("looks.rename")
        case .lookExport:
            return .text("looks.export")
        case .lookDelete:
            return .text("looks.delete")
        // Labelled by their group (#2389): the two wells share
        // the drawn "Ticked rows", so the search join lands each
        // on its own group's title instead (gui.md ▸ #1250).
        case .accentPaint:
            return .text(
                "colors.accent.title",
                help: "colors.ticked_rows.help"
            )
        case .secondAccentPaint:
            return .text(
                "colors.second_accent.title",
                help: "colors.ticked_rows.help"
            )
        }
    }
}
