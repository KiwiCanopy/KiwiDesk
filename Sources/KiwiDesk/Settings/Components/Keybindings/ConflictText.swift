import KiwiDeskCore
import SwiftUI

/// The GUI boundary where a Core `Conflict` becomes readable
/// text (#96). Core detects conflicts in actor-free code that
/// cannot reach `L()` (it is `@MainActor`), so it names what
/// clashed and this file says it in the user's language — the
/// canonical → label split `KeybindingCatalog` already uses.
///
/// The banner's own sentences live in
/// `SettingsModel+ConflictMessages`, which renders the same
/// structure at a different length. This file owns the per-row
/// tooltip.
enum ConflictText {
    /// The tooltip for one row, or nil when the row is empty,
    /// unique, or valid.
    @MainActor
    static func tooltip(
        for binding: KeyBinding,
        in bindings: [KeyBinding]
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
                who
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
    /// The macOS name for this shortcut, in the user's language.
    ///
    /// The switch is **exhaustive on purpose**: a new case in
    /// Core cannot ship without a string here, because the
    /// compiler refuses. That is what makes this mirror
    /// forget-proof without a hand-listed parity test (§5) —
    /// `SystemShortcutNamesTests` only adds that no two cases
    /// share a name, which the compiler cannot see.
    ///
    /// These are Apple's own feature names, so a translation
    /// should follow whatever macOS itself calls them in that
    /// language rather than translating the English literally.
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
        }
    }
}
