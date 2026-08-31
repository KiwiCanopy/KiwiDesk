import Foundation
import KiwiDeskCore

/// Core engine forwarding derivations for SettingsModel.
extension SettingsModel {
    var configURL: URL { core.configURL }
    var displays: [Display] { core.state.workspaces.allDisplays }

    /// Whether the raw Lua editor is currently shown.
    var editingLua: Bool { forcedLuaEditor || showLuaEditor }
}
