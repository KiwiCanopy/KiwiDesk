import Foundation
import KiwiDeskCore

/// Primary Save action classification for Settings footer
/// (`PrimarySaveAction`, #516).
extension SettingsModel {
    /// Primary Save verb classification for Settings footer.
    enum PrimarySaveAction {
        /// Save writes init.lua verbatim.
        case saveLua
        /// Save writes stored profile file.
        case updateStoredProfile
        /// Save updates active profile and applies changes.
        case updateActiveProfile
        /// Save as New Profile modal trigger.
        case saveAsNewProfile
        /// Writes gui.json global settings only when permission is paused
        /// (#516).
        case saveGlobalsOnly
    }

    var primarySaveAction: PrimarySaveAction {
        if editingLua { return .saveLua }
        if editingStoredProfile { return .updateStoredProfile }
        // Permission-paused global changes only write gui.json (#516).
        if permissionPaused, core.isGuiManaged, globalsChanged {
            return .saveGlobalsOnly
        }
        if activeProfile != nil { return .updateActiveProfile }
        return .saveAsNewProfile
    }
}
