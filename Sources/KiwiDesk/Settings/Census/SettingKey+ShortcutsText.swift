/// Shortcuts census slice: each row's text, split from
/// `SettingKey+Shortcuts.swift` at the file ceiling.
extension ShortcutsKey {
    var text: SettingRowText {
        switch self {
        case .kiwiHubNavigationKeys:
            return .none
        case .layers, .openApplications, .pocketApps, .advanced,
            .focusDir,
            .screenLast, .spaceStep, .spaceHistoryStep, .spaceLast,
            .goToSpace,
            .swapDir, .screenMove,
            .moveWindowToTrack, .swapWithTrack,
            .moveToSpace, .moveToSpaceFollow, .focusDesktop,
            .moveToDesktop, .moveToDesktopFollow, .switchToLayer,
            .layoutCycle, .viewPicker, .desktopOverview, .jumpToWindow,
            .jumpToLastApp, .toggleLens:
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
        case .maximize:
            return .text(
                "keybinding.maximize",
                help: "keybinding.maximize.help"
            )
        case .maximizeHeight:
            return .text(
                "keybinding.maximize_height",
                help: "keybinding.maximize_height.help"
            )
        case .maximizeWidth:
            return .text(
                "keybinding.maximize_width",
                help: "keybinding.maximize_width.help"
            )
        case .toggleFloating:
            return .text("keybinding.toggle_floating")
        case .toggleTiling:
            return .text(
                "keybinding.toggle_tiling",
                help: "keybinding.toggle_tiling.help"
            )
        case .toggleKiwiVision:
            return .text("keybinding.toggle_kiwivision")
        case .toggleSpaceBar:
            return .text("keybinding.toggle_space_bar")
        case .toggleAppBar:
            return .text("keybinding.toggle_app_bar")
        case .toggleSticky:
            return .text(
                "keybinding.toggle_sticky",
                help: "keybinding.toggle_sticky.help"
            )
        case .pocket:
            return .text(
                "keybinding.pocket",
                help: "keybinding.pocket.help"
            )
        case .pocketWindow:
            return .text(
                "keybinding.pocket_window",
                help: "keybinding.pocket_window.help"
            )
        case .pocketList:
            return .text(
                "keybinding.pocket_list",
                help: "keybinding.pocket_list.help"
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
                help: "shortcuts.restore_defaults.explain"
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
        case .modifierDragMove:
            return .text("shortcuts.gestures.modifier_drag.move")
        case .modifierDragResize:
            return .text("shortcuts.gestures.modifier_drag.resize")
        case .focusWrap:
            return .text(
                "shortcuts.focus_wrap",
                help: "shortcuts.focus_wrap.help"
            )
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
        case .desktopCue:
            return .text("desktops.cue", help: "desktops.cue.help")
        case .hyperKey:
            return .text(
                "shortcuts.hyper_key",
                help: "shortcuts.hyper_key.help"
            )
        case .shortcutBase:
            return .text("shortcuts.base", help: "shortcuts.base.help")
        case .modifierSides:
            return .text(
                "shortcuts.modifier_sides",
                help: "shortcuts.modifier_sides.help"
            )
        }
    }
}
