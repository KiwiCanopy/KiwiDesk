/// Shortcuts census slice: keybinding families, layers, and Lua bindings.

enum ShortcutsKey: String, CaseIterable, Hashable {
    case layers = "config.layers"
    case layersIcon = "config.layers[].icon"
    /// Which profiles a layer belongs to (#2022).
    case layersReach = "config.layers[].reach"
    case focusDir = "keybinding.focus_dir (x4)"
    /// The previous / next Space in the screen's order (#1655).
    case spaceStep = "keybinding.space_{previous,next}"
    /// Back / forward through the Space history (#1655).
    case spaceHistoryStep = "keybinding.space_{back,forward}"
    /// Which history those two walk (#1655).
    case spaceHistory = "config.spaceHistory"
    case goToSpace = "keybinding.go_to_space (x N spaces)"
    case focusDesktop = "keybinding.focus_desktop (x N desktops)"
    /// The window switcher (#1875), its row named "Show" and the
    /// side's VoiceOver name (#2245).
    case jumpToWindow = "keybinding.show_jump_to_window"
    case toggleKiwiVision = "keybinding.toggle_kiwivision"
    /// One row per live lens (#2103 ruling 42).
    case toggleLens = "keybinding.toggle_lens (x N lenses)"
    case swapDir = "keybinding.swap_dir (x4)"
    case moveWindowToTrack =
        "keybinding.move_window_to_{prev,next}_track"
    case swapWithTrack =
        "keybinding.swap_with_{prev,next}_track"
    case moveToSpace = "keybinding.move_to_space (x N)"
    case moveToSpaceFollow = "keybinding.move_to_space_follow (x N)"
    case moveToDesktop = "keybinding.move_to_desktop (x N desktops)"
    case moveToDesktopFollow =
        "keybinding.move_to_desktop_follow (x N)"
    /// Next / previous layout of the focused Space (#453).
    case layoutCycle = "keybinding.{next,previous}_layout"
    /// KiwiHub's View side, its Layout line at the pointer (#762,
    /// #2309).
    case viewPicker = "keybinding.show_view_picker"
    /// The layouts the cycle walks (#453).
    case modeCycle = "config.modeCycle"
    /// The plate shown after a cycle (#2144): app-wide (#1741).
    case modeCue = "appWide.modeCue"
    /// The key turned into Hyper (#1870): app-wide, per Mac.
    case hyperKey = "appWide.hyperKey"
    /// The Hyper move offer and the Desktop base it writes (#1870),
    /// drafted with the layers.
    case desktopShortcutBase = "config.desktopShortcutBase"
    case growWidth = "keybinding.grow_width"
    case shrinkWidth = "keybinding.shrink_width"
    case growHeight = "keybinding.grow_height"
    case shrinkHeight = "keybinding.shrink_height"
    /// `reset_layout_sizing` on the active Space (#2303).
    case resetSizes = "keybinding.reset_sizes"
    case toggleFloating = "keybinding.toggle_floating"
    case toggleSticky = "keybinding.toggle_sticky"
    case toggleDisplaySticky = "keybinding.toggle_display_sticky"
    case showShortcuts = "keybinding.show_shortcuts"
    case openSettings = "keybinding.open_settings"
    case switchToLayer = "keybinding.switch_to_layer (x N-1)"
    case openApplications = "(rows) shortcuts.open_applications"
    case advanced = "(rows) shortcuts.advanced"
    case `import` = "(action) shortcuts.import"
    case restoreDefaults = "(action) shortcuts.restore_defaults"
    // The scroll gestures (#1656, #1519).
    case scrollPan = "config.scrollGesture.pan"
    case scrollLongSwipes = "config.scrollGesture.longSwipes"
    case scrollStepDistance = "config.scrollGesture.stepDistance"
    case scrollNaturalTrackpad = "config.scrollGesture.naturalTrackpad"
    case scrollNaturalMouse = "config.scrollGesture.naturalMouse"
    case scrollSpaceStep = "config.scrollGesture.spaceStep"
}

extension ShortcutsKey {
    var placement: SettingPlacement {
        switch self {
        case .layers, .layersIcon, .layersReach, .switchToLayer:
            // Surfaces at rest when configured layers exist.
            return .row(
                .shortcuts,
                .layers,
                .immediate,
                gate: .runtime(.layersExist)
            )
        case .focusDir, .spaceStep, .spaceHistoryStep, .spaceHistory,
            .goToSpace:
            return .row(.shortcuts, .focus, .atRest)
        case .toggleKiwiVision, .toggleLens:
            return .row(.shortcuts, .kiwiVisionShortcuts, .atRest)
        // KiwiHub's three sides, one group for one panel (#2265).
        case .jumpToWindow, .showShortcuts, .viewPicker:
            return .row(.shortcuts, .kiwiHub, .atRest)
        case .swapDir, .moveToSpace, .moveToSpaceFollow:
            return .row(.shortcuts, .moveWindows, .atRest)
        // An OFFER until the Track layout is in play (#1440).
        case .moveWindowToTrack, .swapWithTrack:
            return .row(
                .shortcuts,
                .moveWindows,
                .immediate,
                gate: .runtime(.trackInUse)
            )
        // An OFFER until the user takes it (#1125): a Desktop is
        // macOS's arrangement rather than KiwiDesk's, the seed
        // binds none of these, and they scale per Desktop — so
        // they sit behind their own disclosure until one is
        // bound, and at rest in BOTH modes once one is.
        case .focusDesktop:
            return .row(
                .shortcuts,
                .focus,
                .immediate,
                gate: .runtime(.desktopBindingsExist)
            )
        case .moveToDesktop, .moveToDesktopFollow:
            return .row(
                .shortcuts,
                .moveWindows,
                .immediate,
                gate: .runtime(.desktopBindingsExist)
            )
        case .layoutCycle, .modeCycle:
            return .row(.shortcuts, .layout, .atRest)
        case .modeCue:
            // Written at once; greys where init.lua owns the
            // config, as the Desktop switch cue does (#2142).
            return .row(
                .shortcuts,
                .layout,
                .atRest,
                gate: .runtime(.luaOwnsConfig)
            )
        case .hyperKey, .desktopShortcutBase:
            // Above the layer header: it belongs to no layer
            // (#1870). The key is written at once, the offer into
            // the draft; both grey where init.lua owns the config.
            return .row(
                .shortcuts,
                .hyperKey,
                .atRest,
                gate: .runtime(.luaOwnsConfig)
            )
        case .growWidth, .shrinkWidth, .growHeight, .shrinkHeight,
            .resetSizes, .toggleFloating, .toggleSticky,
            .toggleDisplaySticky:
            return .row(.shortcuts, .sizeAndFloat, .atRest)
        case .openApplications:
            return .row(.shortcuts, .openApplications, .atRest)
        // KiwiDesk's own chord, under the group's "KiwiDesk"
        // subheading since the General drawer folded in (#1520).
        case .openSettings:
            return .row(.shortcuts, .openApplications, .atRest)
        case .advanced:
            return .row(.shortcuts, .luaBindings, .showMore)
        case .`import`:
            // Surfaced at rest (never behind disclosure) when init.lua has
            // unadopted shortcuts.
            return .row(
                .shortcuts,
                .luaBindings,
                .atRest,
                gate: .runtime(.luaImportAvailable)
            )
        case .scrollPan, .scrollLongSwipes, .scrollStepDistance,
            .scrollSpaceStep, .scrollNaturalTrackpad,
            .scrollNaturalMouse:
            // The Mouse & trackpad drawer's first group (#1656).
            return .row(.shortcuts, .gestures, .showMore)
        case .restoreDefaults:
            // Surfaced at rest when unseeded defaults are missing.
            return .row(
                .shortcuts,
                .defaultShortcuts,
                .atRest,
                gate: .runtime(.defaultsToRestore)
            )
        }
    }
}

extension ShortcutsKey {
    var text: SettingRowText {
        switch self {
        case .layers, .openApplications, .advanced, .focusDir,
            .spaceStep, .spaceHistoryStep, .goToSpace, .swapDir,
            .moveWindowToTrack, .swapWithTrack,
            .moveToSpace, .moveToSpaceFollow, .focusDesktop,
            .moveToDesktop, .moveToDesktopFollow, .switchToLayer,
            .layoutCycle, .viewPicker, .jumpToWindow, .toggleLens:
            return .dynamic
        case .layersIcon:
            return .text("shortcuts.menu_bar_icon")
        case .layersReach:
            return .text("app_rules.reach")
        case .growWidth:
            return .text("keybinding.grow_width")
        case .shrinkWidth:
            return .text("keybinding.shrink_width")
        case .growHeight:
            return .text("keybinding.grow_height")
        case .shrinkHeight:
            return .text("keybinding.shrink_height")
        case .resetSizes:
            return .text("keybinding.reset_sizes")
        case .toggleFloating:
            return .text("keybinding.toggle_floating")
        case .toggleKiwiVision:
            return .text("keybinding.toggle_kiwivision")
        case .toggleSticky:
            return .text(
                "keybinding.toggle_sticky",
                help: "keybinding.toggle_sticky.help"
            )
        case .toggleDisplaySticky:
            return .text(
                "keybinding.toggle_display_sticky",
                help: "keybinding.toggle_display_sticky.help"
            )
        case .showShortcuts:
            return .text("keybinding.show_shortcuts")
        case .openSettings:
            return .text("keybinding.open_settings")
        case .`import`:
            return .text("shortcuts.import", help: "shortcuts.import.help")
        case .restoreDefaults:
            return .text(
                "shortcuts.restore_defaults",
                help: "shortcuts.restore_defaults.help"
            )
        case .scrollPan:
            return .text("shortcuts.gestures.scroll.pan")
        case .scrollLongSwipes:
            return .text("shortcuts.gestures.scroll.long_swipes")
        case .scrollStepDistance:
            return .text("shortcuts.gestures.scroll.step_distance")
        case .scrollNaturalTrackpad:
            return .text("shortcuts.gestures.scroll.trackpad")
        case .scrollNaturalMouse:
            return .text("shortcuts.gestures.scroll.mouse")
        case .scrollSpaceStep:
            return .text("shortcuts.gestures.scroll.space_step")
        case .spaceHistory:
            return .text(
                "shortcuts.space_history.kept",
                help: "shortcuts.space_history.choice_help"
            )
        case .modeCycle:
            return .text(
                "shortcuts.mode_cycle",
                help: "shortcuts.mode_cycle.help"
            )
        case .modeCue:
            return .text(
                "shortcuts.mode_cue",
                help: "shortcuts.mode_cue.help"
            )
        case .hyperKey:
            return .text(
                "shortcuts.hyper_key",
                help: "shortcuts.hyper_key.help"
            )
        case .desktopShortcutBase:
            return .text("shortcuts.hyper_move.offer")
        }
    }
}
