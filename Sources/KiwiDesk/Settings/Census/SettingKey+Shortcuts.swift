/// Shortcuts: keybinding families (one case per family — the
/// xN row expansions are instances, not settings), layers,
/// and the Lua-binding rows.

enum ShortcutsKey: String, CaseIterable, Hashable {
    case layers = "config.layers"
    case layersIcon = "config.layers[].icon"
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
    case switchToLayer = "keybinding.switch_to_layer (x N-1)"
    case openApplications = "(rows) shortcuts.open_applications"
    case advanced = "(rows) shortcuts.advanced"
    case `import` = "(action) shortcuts.import"
}

extension ShortcutsKey {
    var placement: SettingPlacement {
        switch self {
        case .layers, .layersIcon, .switchToLayer:
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
            return .row(
                .shortcuts,
                .luaBindings,
                .showMore,
                gate: .runtime(.luaImportAvailable)
            )
        }
    }
}

extension ShortcutsKey {
    var text: SettingRowText {
        switch self {
        // Family keys (`keybinding.focus_dir` = "Focus window
        // %1$@" …) carry positional specifiers and are only
        // ever formatted per instance — a family ROW's title is
        // runtime-composed, so these are `.dynamic`, not the
        // template key.
        case .layers, .openApplications, .advanced, .focusDir,
            .goToSpace, .swapDir, .moveWindowToTrack, .swapWithTrack,
            .moveToSpace, .moveToSpaceFollow, .switchToLayer:
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
        case .`import`:
            return .text("shortcuts.import", help: "shortcuts.import.help")
        }
    }
}
