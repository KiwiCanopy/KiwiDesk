import KiwiDeskCore
import SwiftUI

/// Keybinding conflict tooltip and localized system shortcut names (#96).
enum ConflictText {
    /// Tooltip text for conflicting keybinding row (`KeybindingCatalog`, #96).
    @MainActor
    static func tooltip(
        for binding: KeyBinding,
        in bindings: [KeyBinding],
        config: GuiConfig
    ) -> String? {
        guard
            let conflict = KeybindingConflicts.conflict(
                for: binding,
                in: bindings
            )
        else { return nil }
        switch conflict.target {
        case .unrecognized:
            return L(
                "keybinding.conflict.tooltip.unrecognized",
                "Not a recognized shortcut."
            )
        case .otherBinding(let who):
            return L(
                "keybinding.conflict.tooltip.other_binding",
                "Already bound in this layer: %1$@",
                KeybindingCatalog.localizedLabel(
                    for: who,
                    config: config
                )
            )
        case .systemShortcut(let shortcut):
            return L(
                "keybinding.conflict.tooltip.system",
                "Conflicts with macOS: %1$@",
                shortcut.localizedName
            )
        }
    }
}

extension SystemShortcut {
    /// Localized macOS system shortcut name. The switch is
    /// exhaustive on purpose: a new Core case cannot ship without
    /// a string here — the compiler is the parity guard;
    /// `SystemShortcutNamesTests` only adds that no two cases
    /// share a name. These are Apple's feature names, so a
    /// translation follows whatever macOS calls them (#768).
    @MainActor
    var localizedName: String {
        switch self {
        case .spotlight:
            return L("system_shortcut.spotlight", "Spotlight")
        case .appSwitcher:
            return L(
                "system_shortcut.app_switcher",
                "App Switcher"
            )
        case .quitApp:
            return L("system_shortcut.quit_app", "Quit App")
        case .closeWindow:
            return L(
                "system_shortcut.close_window",
                "Close Window"
            )
        case .minimize:
            return L("system_shortcut.minimize", "Minimize")
        case .hideApp:
            return L("system_shortcut.hide_app", "Hide App")
        case .forceQuit:
            return L("system_shortcut.force_quit", "Force Quit")
        // These two name APPLE's shortcut rows, so they keep
        // "Space" while the app says Desktop (#768, owner ruling
        // 2026-08-12): the string exists so a user can find that
        // row in System Settings, where macOS says "space" —
        // renaming it would point at a label not on screen. The
        // carve-out is written in config-vocabulary.md.
        case .missionControlSpaceLeft:
            return L(
                "system_shortcut.mission_control_space_left",
                "Mission Control: Space Left"
            )
        case .missionControlSpaceRight:
            return L(
                "system_shortcut.mission_control_space_right",
                "Mission Control: Space Right"
            )
        case .missionControl:
            return L(
                "system_shortcut.mission_control",
                "Mission Control"
            )
        case .appWindows:
            return L(
                "system_shortcut.app_windows",
                "App Windows"
            )
        case .zoomToggle:
            return L(
                "system_shortcut.zoom_toggle",
                "Zoom On/Off"
            )
        case .zoomIn:
            return L("system_shortcut.zoom_in", "Zoom In")
        case .zoomOut:
            return L("system_shortcut.zoom_out", "Zoom Out")
        case .dockHiding:
            return L(
                "system_shortcut.dock_hiding",
                "Turn Dock Hiding On/Off"
            )
        case .finderSearch:
            return L(
                "system_shortcut.finder_search",
                "Finder Search Window"
            )
        case .screenshot:
            return L("system_shortcut.screenshot", "Screenshot")
        case .screenshotSelection:
            return L(
                "system_shortcut.screenshot_selection",
                "Screenshot Selection"
            )
        case .screenshotTools:
            return L(
                "system_shortcut.screenshot_tools",
                "Screenshot Tools"
            )
        case .inputSourceNext:
            return L(
                "system_shortcut.input_source_next",
                "Select next source in Input menu"
            )
        case .invertColors:
            return L(
                "system_shortcut.invert_colors",
                "Invert Colors"
            )
        case .increaseContrast:
            return L(
                "system_shortcut.increase_contrast",
                "Increase Contrast"
            )
        case .decreaseContrast:
            return L(
                "system_shortcut.decrease_contrast",
                "Decrease Contrast"
            )
        }
    }
}
