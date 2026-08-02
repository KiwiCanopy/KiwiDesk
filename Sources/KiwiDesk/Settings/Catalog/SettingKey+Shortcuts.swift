/// Shortcuts: keybinding families (one case per family — the
/// xN row expansions are instances, not settings), layers,
/// and the Lua-binding rows.

enum ShortcutsKey: String, CaseIterable, Hashable {
    case layers = "config.modes"
    case layersIcon = "config.modes[].icon"
    case focusDir = "keybinding.focus_dir (x4)"
    case goToSpace = "keybinding.go_to_space (x N spaces)"
    case swapDir = "keybinding.swap_dir (x4)"
    case moveWindowToTrack = "keybinding.move_window_to_track (x2)"
    case swapWithTrack = "keybinding.swap_with_track (x2)"
    case moveToSpace = "keybinding.move_to_space (x N)"
    case moveToSpaceFollow = "keybinding.move_to_space_follow (x N)"
    case growWidth = "keybinding.grow_width"
    case shrinkWidth = "keybinding.shrink_width"
    case growHeight = "keybinding.grow_height"
    case shrinkHeight = "keybinding.shrink_height"
    case toggleFloating = "keybinding.toggle_floating"
    case toggleSticky = "keybinding.toggle_sticky"
    case toggleDisplaySticky = "keybinding.toggle_display_sticky"
    case showShortcuts = "keybinding.show_shortcuts"
    case switchToMode = "keybinding.switch_to_mode (x N-1)"
    case openApplications = "(rows) shortcuts.open_applications"
    case advanced = "(rows) shortcuts.advanced"
    case `import` = "(action) shortcuts.import"
}

extension ShortcutsKey {
    var placement: SettingPlacement {
        switch self {
        case .layers, .layersIcon, .switchToMode:
            return .row(.shortcuts, .layers, .showMore)
        case .focusDir, .goToSpace:
            return .row(.shortcuts, .focus, .atRest)
        case .swapDir, .moveWindowToTrack, .swapWithTrack, .moveToSpace,
            .moveToSpaceFollow:
            return .row(.shortcuts, .moveWindows, .atRest)
        case .growWidth, .shrinkWidth, .growHeight, .shrinkHeight,
            .toggleFloating, .toggleSticky, .toggleDisplaySticky:
            return .row(.shortcuts, .sizeAndFloat, .atRest)
        case .showShortcuts:
            return .row(.shortcuts, .generalKeys, .showMore)
        case .openApplications:
            return .row(.shortcuts, .openApplications, .atRest)
        case .advanced:
            return .row(.shortcuts, .luaBindings, .showMore)
        case .`import`:
            // conditional
            return .row(.shortcuts, .luaBindings, .showMore)
        }
    }
}

extension ShortcutsKey {
    var text: SettingRowText {
        switch self {
        case .layers, .openApplications, .advanced:
            return .dynamic
        case .layersIcon:
            return .text("shortcuts.menu_bar_icon")
        case .focusDir:
            return .text("keybinding.focus_dir")
        case .goToSpace:
            return .text("keybinding.go_to_space")
        case .swapDir:
            return .text("keybinding.swap_dir")
        case .moveWindowToTrack:
            return .text("keybinding.move_window_to_track")
        case .swapWithTrack:
            return .text("keybinding.swap_with_track")
        case .moveToSpace:
            return .text("keybinding.move_to_space")
        case .moveToSpaceFollow:
            return .text("keybinding.move_to_space_follow")
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
        case .switchToMode:
            return .text("keybinding.switch_to_mode")
        case .`import`:
            return .text("shortcuts.import", help: "shortcuts.import.help")
        }
    }
}
