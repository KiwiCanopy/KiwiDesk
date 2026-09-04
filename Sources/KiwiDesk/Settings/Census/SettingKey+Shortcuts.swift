/// Shortcuts census slice: keybinding families, layers, and Lua bindings.

enum ShortcutsKey: String, CaseIterable, Hashable {
    case layers = "config.layers"
    case layersIcon = "config.layers[].icon"
    case focusDir = "keybinding.focus_dir (x4)"
    case goToSpace = "keybinding.go_to_space (x N spaces)"
    case focusDesktop = "keybinding.focus_desktop (x N desktops)"
    case swapDir = "keybinding.swap_dir (x4)"
    case moveWindowToTrack = "keybinding.move_window_to_track (x2)"
    case swapWithTrack = "keybinding.swap_with_track (x2)"
    case moveToSpace = "keybinding.move_to_space (x N)"
    case moveToSpaceFollow = "keybinding.move_to_space_follow (x N)"
    case moveToDesktop = "keybinding.move_to_desktop (x N desktops)"
    case moveToDesktopFollow =
        "keybinding.move_to_desktop_follow (x N)"
    case growWidth = "keybinding.grow_width"
    case shrinkWidth = "keybinding.shrink_width"
    case growHeight = "keybinding.grow_height"
    case shrinkHeight = "keybinding.shrink_height"
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
}

extension ShortcutsKey {
    var placement: SettingPlacement {
        switch self {
        case .layers, .layersIcon, .switchToLayer:
            // Surfaces at rest when configured layers exist.
            return .row(
                .shortcuts,
                .layers,
                .immediate,
                gate: .runtime(.layersExist)
            )
        case .focusDir, .goToSpace:
            return .row(.shortcuts, .focus, .atRest)
        case .swapDir, .moveWindowToTrack, .swapWithTrack, .moveToSpace,
            .moveToSpaceFollow:
            return .row(.shortcuts, .moveWindows, .atRest)
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
        case .growWidth, .shrinkWidth, .growHeight, .shrinkHeight,
            .toggleFloating, .toggleSticky, .toggleDisplaySticky:
            return .row(.shortcuts, .sizeAndFloat, .atRest)
        case .showShortcuts, .openSettings:
            return .row(.shortcuts, .generalKeys, .showMore)
        case .openApplications:
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
            .goToSpace, .swapDir, .moveWindowToTrack, .swapWithTrack,
            .moveToSpace, .moveToSpaceFollow, .focusDesktop,
            .moveToDesktop, .moveToDesktopFollow, .switchToLayer:
            return .dynamic
        case .layersIcon:
            return .text("shortcuts.menu_bar_icon")
        case .growWidth:
            return .text("keybinding.grow_width")
        case .shrinkWidth:
            return .text("keybinding.shrink_width")
        case .growHeight:
            return .text("keybinding.grow_height")
        case .shrinkHeight:
            return .text("keybinding.shrink_height")
        case .toggleFloating:
            return .text("keybinding.toggle_floating")
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
        }
    }
}
