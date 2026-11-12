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
    /// App-wide (#3238): the speed preset, its Off the stored flag;
    /// its speeds write the lengths, which are Lua-only rows.
    case animationSpeed = "appWide.animationReduceMotion"
    /// App-wide (#1741), not an `AnimationSettings` field: how a
    /// Space switch shows itself and the slide's pace (#2524).
    case spaceTransition = "appWide.spaceTransition"
    /// The scroll Space step's own pick (#2971), the same shape.
    case spaceScrollTransition = "appWide.spaceScrollTransition"
    case spaceSlideDuration = "appWide.spaceSlideDuration"
    case animationsOnWindowResize = "settings.animations.onWindowResize"
    case animationsOnWindowSwap = "settings.animations.onWindowSwap"
    case animationsOnRelayout = "settings.animations.onRelayout"
    case animationsOnStateChange = "settings.animations.onStateChange"
    case animationsDurationMS = "appWide.animationDurationMS"
    case animationsOnScrolling = "settings.animations.onScrolling"
    case animationsScrollDurationMS =
        "appWide.animationScrollDurationMS"
    case animationsOnExpand = "settings.animations.onExpand"
    case animationsOnPeek = "settings.animations.onPeek"
    case animationsOnReveal = "settings.animations.onReveal"
    case animationsExpandDurationMS =
        "appWide.animationExpandDurationMS"
    case animationsRevealDurationMS =
        "appWide.animationRevealDurationMS"
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
    /// The gallery's doors (#1740); Simple's Browse tile is this
    /// row too.
    case lookBrowse = "(action) look.browse"
    case lookImport = "(action) look.import"
    case lookShare = "(action) look.share"
    case lookRename = "(action) look.rename"
    case lookExport = "(action) look.export"
    case lookDelete = "(action) look.delete"
    /// The authored look the current one was picked from (#1740),
    /// which Share and Save credit; a pick writes it.
    case lookOrigin = "settings.lookOrigin"
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
        case .animationsMaster, .animationSpeed:
            return .row(.coloursAndMotion, .motion, .atRest)
        case .spaceSlideDuration:
            // Lua-only: the speed preset is Settings' one pace
            // control (owner ruling, 2026-11-12, #3238).
            return .luaOnly
        case .spaceTransition, .spaceScrollTransition:
            // App-wide (#1741), so they grey where init.lua owns
            // the config (#2142).
            return .row(
                .coloursAndMotion,
                .spaceSwitch,
                .atRest,
                gate: .runtime(.luaOwnsConfig)
            )
        case .animationsOnWindowResize,
            .animationsOnWindowSwap, .animationsOnRelayout,
            .animationsOnStateChange:
            return .row(
                .coloursAndMotion,
                .motion,
                .showMore,
                gate: .setting(.colours(.animationsMaster))
            )
        case .animationsOnExpand:
            // KiwiShelf ▸ Show ▸ Durations; its length is Lua-only
            // (#3236).
            return .row(.bars, .kiwishelf, .showMore)
        case .animationsOnPeek:
            // The peeks' motion off, Lua-only (#2563).
            return .luaOnly
        case .animationsRevealDurationMS:
            // Lua-only, as the expand's length (owner ruling,
            // 2026-11-12, #3236).
            return .luaOnly
        case .animationsOnReveal:
            // KiwiShelf ▸ Show ▸ Durations, greyed with the Reveal
            // row while no bar hides (owner ruling, 2026-10-21, #3236).
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: .runtime(.noBarHides)
            )
        case .animationsExpandDurationMS:
            // Lua-only beside its Settings switch (owner ruling,
            // 2026-11-12, #3236).
            return .luaOnly
        case .animationsOnScrolling:
            return .row(.layoutDefaults, .scrolling, .atRest)
        case .animationsDurationMS, .animationsScrollDurationMS:
            // Lua-only: the speed preset is to be Settings' one pace
            // control (owner ruling, 2026-11-12, #3238).
            return .luaOnly
        case .paletteApply, .paletteSave, .paletteImport:
            return .row(.coloursAndMotion, .palettes, .atRest)
        case .paletteRename, .paletteExport, .paletteDelete:
            // Context menu actions pinned by ColorsCensusRenderTests.
            return .row(.coloursAndMotion, .palettes, .showMore)
        case .lookApply, .lookSave, .lookBrowse, .lookImport,
            .lookShare:
            return .row(.coloursAndMotion, .looks, .atRest)
        case .lookOrigin:
            // Written by a pick, drawn by no control: the save pill
            // narrates it, search never lands on it.
            return .internalOnly
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
        case .animationSpeed:
            return .text(
                "behavior.animations.speed",
                help: "behavior.animations.speed.help"
            )
        case .spaceTransition:
            return .text(
                "animations.space_transition",
                help: "animations.space_transition.help"
            )
        case .spaceScrollTransition:
            return .text("animations.space_scroll_transition")
        case .spaceSlideDuration:
            return .none
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
        case .animationsOnExpand:
            return .text(
                "kiwishelf.on_expand",
                help: "kiwishelf.on_expand.help"
            )
        case .animationsOnPeek:
            return .none
        case .animationsOnReveal:
            return .text(
                "kiwishelf.on_reveal",
                help: "kiwishelf.on_reveal.help"
            )
        case .animationsRevealDurationMS, .animationsExpandDurationMS:
            return .none
        case .animationsOnScrolling:
            return .text(
                "scroll_grid.animate_focus_shifts",
                help: "scroll_grid.animate_focus_shifts.help"
            )
        case .animationsDurationMS, .animationsScrollDurationMS:
            return .none
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
            return .text("looks.reach.choice")
        case .lookSave:
            return .text("looks.save_current")
        case .lookBrowse:
            return .text("looks.browse")
        case .lookImport:
            return .text("looks.import")
        case .lookShare:
            return .text("looks.share")
        case .lookRename:
            return .text("looks.rename")
        case .lookExport:
            return .text("looks.export")
        case .lookDelete:
            return .text("looks.delete")
        case .lookOrigin:
            return .none
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
