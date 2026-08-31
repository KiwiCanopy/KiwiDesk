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
        // Ahead of both profile verbs and only them: those write
        // no monitor set and must not be rerouted (#516). Asks
        // `core.isGuiManaged`, never `savedSidecar != nil` — §5
        // keeps ONE ownership predicate, and a stale non-nil
        // snapshot would let this save re-create gui.json and
        // seize ownership from init.lua outside the sanctioned
        // adopt path. An unknown baseline is not evidence of an
        // edit.
        if permissionPaused, core.isGuiManaged, globalsChanged {
            return .saveGlobalsOnly
        }
        if activeProfile != nil { return .updateActiveProfile }
        return .saveAsNewProfile
    }
}
