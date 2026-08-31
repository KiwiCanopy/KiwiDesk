import Foundation
import KiwiDeskCore

/// Core engine forwarding derivations for SettingsModel. Small on
/// purpose: a derivation belongs beside the value it derives FROM
/// (edit-target reads sit with their state machine); a value
/// lands here only when it has no subsystem.
extension SettingsModel {
    var configURL: URL { core.configURL }
    var displays: [Display] { core.state.workspaces.allDisplays }

    /// Whether the raw Lua editor is currently shown.
    var editingLua: Bool { forcedLuaEditor || showLuaEditor }
}
