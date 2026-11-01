/// Shortcuts census slice: keybinding families, layers, and Lua bindings.

enum ShortcutsKey: String, CaseIterable, Hashable {
    case layers = "config.layers"
    case layersIcon = "config.layers[].icon"
    /// Which profiles a layer belongs to (#2022).
    case layersReach = "config.layers[].reach"
    /// What the focus keys do at the last window (#2493).
    case focusWrap = "config.focusWrap"
    case focusDir = "keybinding.focus_dir (x4)"
    /// Go to the screen the focus was on before (#2512).
    case screenLast = "keybinding.focus_display_last"
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
    /// Each bar's show/hide shortcut (#761).
    case toggleSpaceBar = "keybinding.toggle_space_bar"
    case toggleAppBar = "keybinding.toggle_app_bar"
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
    /// The plate shown after a Desktop switch KiwiDesk makes
    /// (#2142): app-wide (#1741), first in macOS Desktops (#2655).
    case desktopCue = "appWide.desktopCue"
    /// The key turned into Hyper (#1870): app-wide, per Mac.
    case hyperKey = "appWide.hyperKey"
    /// KiwiHub's navigation key alternatives (#2600): app-wide,
    /// Lua-only.
    case kiwiHubNavigationKeys = "appWide.kiwiHubKeys"

    /// Whether shortcuts keep a modifier's side (#2601): app-wide.
    case modifierSides = "appWide.modifierSides"
    /// The "Shortcuts use" switch's base (#2460), drafted with the
    /// layers it moves.
    case shortcutBase = "config.shortcutBase"
    case growWidth = "keybinding.grow_width"
    case shrinkWidth = "keybinding.shrink_width"
    case growHeight = "keybinding.grow_height"
    case shrinkHeight = "keybinding.shrink_height"
    /// `reset_layout_sizing` on the active Space (#2303).
    case resetSizes = "keybinding.reset_sizes"
    /// `toggle_maximized` (#2448).
    case maximize = "keybinding.maximize"
    case toggleFloating = "keybinding.toggle_floating"
    case toggleSticky = "keybinding.toggle_sticky"
    /// `pocket` (#2446), in pin's place since pin went Lua-only.
    case pocket = "keybinding.pocket"
    /// `toggle_pocket_window` (#2675).
    case pocketWindow = "keybinding.pocket_window"
    /// What the pocket holds (#2678); where it stands is
    /// KiwiShelf's (`SettingKey+KiwiShelf`).
    case pocketCapacity = "appWide.pocketCapacity"
    /// Each app's own Pocket key, a row per app (#2612).
    case pocketApps = "(rows) shortcuts.pocket_apps"
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
        case .kiwiHubNavigationKeys:
            return .luaOnly
        case .layers:
            // The strip: the offer to make the first layer, behind
            // the Layers card's disclosure (#2654).
            return .row(.shortcuts, .layers, .showMore)
        case .layersIcon, .layersReach, .switchToLayer:
            // Exist once a layer does; the card then opens on
            // arrival (#2654).
            return .row(
                .shortcuts,
                .layers,
                .immediate,
                gate: .runtime(.layersExist)
            )
        case .focusWrap, .focusDir, .screenLast, .spaceStep,
            .spaceHistoryStep, .spaceHistory, .goToSpace:
            return .row(.shortcuts, .focus, .atRest)
        // One card for what shows and hides: KiwiHub's sides
        // (#2265), the bars (#761), KiwiVision and its lenses.
        case .jumpToWindow, .showShortcuts, .viewPicker,
            .toggleSpaceBar, .toggleAppBar,
            .toggleKiwiVision, .toggleLens:
            return .row(.shortcuts, .showHide, .atRest)
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
        // One section for every Desktop verb (#2655): the seeded
        // Go to Desktop at rest, the moves behind its drawer.
        case .desktopCue:
            // Written at once; greys where init.lua owns the
            // config, as the layout plate's switch does (#2142),
            // and hides with its section without the bridge.
            return .row(
                .shortcuts,
                .macosDesktops,
                .atRest,
                gate: .runtimeAnyOf([
                    .luaOwnsConfig, .desktopBridgeAbsent,
                ])
            )
        case .focusDesktop:
            return .row(.shortcuts, .macosDesktops, .atRest)
        case .moveToDesktop, .moveToDesktopFollow:
            return .row(.shortcuts, .macosDesktops, .showMore)
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
        case .hyperKey, .shortcutBase, .modifierSides:
            // Above the layer header: it belongs to no layer
            // (#1870). Behind the card's disclosure, which opens on
            // arrival once in use (#2654). The key and the sides
            // switch (#2601) are written at once, the base into the
            // draft (#2460); all grey where init.lua owns the config.
            return .row(
                .shortcuts,
                .modifierKeys,
                .showMore,
                gate: .runtime(.luaOwnsConfig)
            )
        case .growWidth, .shrinkWidth, .growHeight, .shrinkHeight,
            .resetSizes, .maximize, .toggleFloating, .toggleSticky:
            return .row(.shortcuts, .sizeAndFloat, .atRest)
        // Its own card (#2680): what it holds, then its two keys;
        // where it sits is KiwiShelf's (#2678).
        case .pocket, .pocketWindow, .pocketCapacity, .pocketApps:
            return .row(.shortcuts, .pocket, .atRest)
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
        case .kiwiHubNavigationKeys:
            return .none
        case .layers, .openApplications, .pocketApps, .advanced,
            .focusDir,
            .screenLast, .spaceStep, .spaceHistoryStep, .goToSpace,
            .swapDir,
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
        case .maximize:
            return .text(
                "keybinding.maximize",
                help: "keybinding.maximize.help"
            )
        case .toggleFloating:
            return .text("keybinding.toggle_floating")
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
        case .pocketCapacity:
            return .text("pocket.capacity", help: "pocket.capacity.help")
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
