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
        // Global changes while the core is not running only write
        // gui.json (#516, #2050).
        if coreHold != .running, core.isGuiManaged, globalsChanged {
            return .saveGlobalsOnly
        }
        if activeProfile != nil { return .updateActiveProfile }
        return .saveAsNewProfile
    }

    /// The one primary Save (#2049): the footer's slot, the close /
    /// quit question and `FitGapsAction` all read these, so their
    /// verb, gate and effect cannot drift apart.
    var primarySaveLabel: String {
        primarySaveAction == .saveAsNewProfile
            ? L("footer.save_as_new_profile", "Save as New Profile…")
            : L("footer.save", "Save")
    }

    /// Whether the primary Save can run now.
    var primarySaveEnabled: Bool {
        switch primarySaveAction {
        case .saveLua, .updateStoredProfile:
            return isDirty
        case .saveGlobalsOnly:
            return isDirty && core.isGuiManaged
        case .updateActiveProfile:
            // Blocked while permission is paused (#335).
            return profileSaveBlockedReason == nil && updateEnabled
                && (isDirty || profileDirty)
        case .saveAsNewProfile:
            return profileSaveBlockedReason == nil
        }
    }

    /// Why the primary Save is greyed, where a reason exists.
    var primarySaveBlockedReason: String? {
        switch primarySaveAction {
        case .updateActiveProfile:
            return profileSaveBlockedReason ?? updateHint
        case .saveAsNewProfile:
            return profileSaveBlockedReason
        case .saveLua, .updateStoredProfile, .saveGlobalsOnly:
            return nil
        }
    }

    /// Runs the primary Save. One that needs a name asks the
    /// footer for its naming prompt (`newProfileNamingRequested`).
    func performPrimarySave() {
        switch primarySaveAction {
        case .saveLua: saveLuaSource()
        case .updateStoredProfile: saveEditedProfile()
        case .updateActiveProfile: updateActiveProfile()
        case .saveGlobalsOnly: saveGlobalsWhilePaused()
        case .saveAsNewProfile: newProfileNamingRequested = true
        }
    }
}
