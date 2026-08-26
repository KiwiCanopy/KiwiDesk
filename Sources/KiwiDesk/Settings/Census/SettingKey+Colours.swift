/// Animations (`AnimationSettings`) and palette actions.

enum ColoursKey: String, CaseIterable, Hashable {
    case animationsMaster = "settings.animations (master)"
    case animationsOnSpaceChange = "settings.animations.onSpaceChange"
    case animationsOnWindowResize = "settings.animations.onWindowResize"
    case animationsOnWindowSwap = "settings.animations.onWindowSwap"
    case animationsOnRelayout = "settings.animations.onRelayout"
    case animationsDurationMS = "settings.animations.durationMS"
    case animationsOnScrolling = "settings.animations.onScrolling"
    case animationsScrollDurationMS =
        "settings.animations.scrollDurationMS"
    case paletteApply = "(action) palette.apply"
    case paletteSave = "(action) palette.save"
    case paletteRename = "(action) palette.rename"
    case paletteExport = "(action) palette.export"
    case paletteDelete = "(action) palette.delete"
    case paletteImport = "(action) palette.import"
    case paletteNeonGlowHint = "(link) palettes.neon_glow_hint"
}

extension ColoursKey {
    var placement: SettingPlacement {
        switch self {
        case .animationsMaster:
            return .row(.coloursAndMotion, .motion, .atRest)
        case .animationsOnSpaceChange, .animationsOnWindowResize,
            .animationsOnWindowSwap, .animationsOnRelayout,
            .animationsDurationMS:
            // The whole gated group follows the master toggle
            // (`MotionCard.disclosure`); the Reduce Motion grey
            // is the .motion CONTAINER gate.
            return .row(
                .coloursAndMotion,
                .motion,
                .showMore,
                gate: .setting(.colours(.animationsMaster))
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
            // The shelf's own affordances: a tile applies, the
            // trailing tile saves, Import sits on the group
            // header. All three are visible at rest, which is
            // what the tier means.
            return .row(.coloursAndMotion, .palettes, .atRest)
        case .paletteRename, .paletteExport, .paletteDelete:
            // The per-palette CONTEXT MENU. `.showMore` is the
            // nearest true tier — not visible at rest, one
            // interaction away — and the tier vocabulary has no
            // case of its own for a menu. Recorded here rather
            // than left as a wiring detail the census cannot
            // see: `ColorsCensusRenderTests` pins this set
            // against the menu's own list, so an action added
            // to the menu without a census row still reds.
            return .row(.coloursAndMotion, .palettes, .showMore)
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
        case .animationsMaster:
            return .text(
                "behavior.animations.master",
                help: "behavior.animations.master.help"
            )
        case .animationsOnSpaceChange:
            return .text(
                "behavior.animations.space_change",
                caption: "behavior.animations.space_change.caption"
            )
        case .animationsOnWindowResize:
            return .text("behavior.animations.window_resize")
        case .animationsOnWindowSwap:
            return .text("behavior.animations.window_swap")
        case .animationsOnRelayout:
            return .text("behavior.animations.relayout")
        case .animationsDurationMS:
            return .text("behavior.animations.duration")
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
        }
    }
}
