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
    /// Send the window to the last screen, or follow it (#3117).
    case screenMove = "keybinding.move_to_display_last{,_follow}"
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
    /// KiwiHub's View side, its Layout line at the pointer (#762, #2309).
    case viewPicker = "keybinding.show_view_picker"
    /// KiwiHub's Desktops side (#1229).
    case desktopOverview = "keybinding.show_desktop_overview"
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
    /// `toggle_maximized(axis)` (#3062).
    case maximizeHeight = "keybinding.maximize_height"
    case maximizeWidth = "keybinding.maximize_width"
    case toggleFloating = "keybinding.toggle_floating"
    /// `toggle_tiling` (#3008).
    case toggleTiling = "keybinding.toggle_tiling"
    case toggleSticky = "keybinding.toggle_sticky"
    /// `pocket` (#2446), in pin's place since pin went Lua-only.
    case pocket = "keybinding.pocket"
    /// `toggle_pocket_window` (#2675).
    case pocketWindow = "keybinding.pocket_window"
    /// `pocket.toggle_list` (#2974).
    case pocketList = "keybinding.pocket_list"
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
    // The modifier drags (#2447): each row's chord and start.
    case modifierDragMove = "config.modifierDrag.move"
    case modifierDragResize = "config.modifierDrag.resize"
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
            .desktopOverview, .toggleSpaceBar, .toggleAppBar,
            .toggleKiwiVision, .toggleLens:
            return .row(.shortcuts, .showHide, .atRest)
        case .swapDir, .screenMove, .moveToSpace, .moveToSpaceFollow:
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
            .resetSizes, .maximize, .maximizeHeight, .maximizeWidth,
            .toggleFloating, .toggleTiling, .toggleSticky:
            return .row(.shortcuts, .sizeAndFloat, .atRest)
        // Its own card (#2680): its keys; where it sits and when it
        // shows are KiwiShelf's (#2678, #2978).
        case .pocket, .pocketWindow, .pocketList, .pocketApps:
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
            // Drawn in the Default shortcuts row (#3074) when init.lua
            // has unadopted shortcuts; its container stays Lua bindings.
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
        case .modifierDragMove, .modifierDragResize:
            // Mouse & trackpad ▸ On your windows (#2447).
            return .row(.shortcuts, .gestures, .showMore)
        case .restoreDefaults:
            // Always drawn; greys at the defaults or on another layer (#3074).
            return .row(
                .shortcuts,
                .defaultShortcuts,
                .atRest,
                gate: .runtime(.defaultsToRestore)
            )
        }
    }
}
