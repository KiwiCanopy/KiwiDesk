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

    /// The one primary Save (#2049): the footer's slot and the
    /// close / quit question both read these, so their verb, gate
    /// and effect cannot drift apart. `FitGapsAction` names the
    /// verb off `primarySaveAction` with literal labels, which
    /// #818's interpolation guard reads.
    var primarySaveLabel: String {
        primarySaveAction == .saveAsNewProfile
            ? L("footer.save_as_new_profile", "Save as New Profile…")
            : L("footer.save", "Save")
    }

    /// Whether the primary Save can run now.
    var primarySaveEnabled: Bool {
        // A newer build's file latches every structured Save up
        // front, before any of its writes (#2324 ruling 2).
        if activeSaveLatch != nil { return false }
        switch primarySaveAction {
        case .saveLua, .updateStoredProfile:
            return isDirty
        case .saveGlobalsOnly:
            return isDirty && core.isGuiManaged
        case .updateActiveProfile:
            // Blocked while permission is paused (#335).
            // A live change not saved is Save's to keep (#2262).
            return profileSaveBlockedReason == nil && updateEnabled
                && (isDirty || profileDirty || liveUnsaved)
        case .saveAsNewProfile:
            return profileSaveBlockedReason == nil
        }
    }

    /// Why the primary Save is greyed, where a reason exists.
    var primarySaveBlockedReason: String? {
        if let activeSaveLatch {
            return NewerFormatText.saveBlocked(activeSaveLatch)
        }
        switch primarySaveAction {
        case .updateActiveProfile:
            return profileSaveBlockedReason ?? updateHint
        case .saveAsNewProfile:
            return profileSaveBlockedReason
        case .saveLua, .updateStoredProfile, .saveGlobalsOnly:
            return nil
        }
    }

    /// The newer-format latch over the primary Save; an `init.lua`
    /// Save writes no format-stamped file and is never latched.
    var activeSaveLatch: NewerFormatOnDisk? {
        primarySaveAction == .saveLua ? nil : writeLatch
    }

    /// Runs the primary Save. One that needs a name asks the
    /// footer for its naming prompt (`newProfileNamingRequested`).
    func performPrimarySave() {
        // Read again here: a newer file may have landed since the
        // last refresh, and the refusal must precede every write.
        if primarySaveAction != .saveLua {
            writeLatch = core.guiConfigWriteLatch()
        }
        guard activeSaveLatch == nil else { return }
        // Settings another Mac changed too are picked first (#2450).
        guard !reviewSyncConflicts() else { return }
        switch primarySaveAction {
        case .saveLua: saveLuaSource()
        case .updateStoredProfile: saveEditedProfile()
        case .updateActiveProfile: updateActiveProfile()
        case .saveGlobalsOnly: saveGlobalsWhilePaused()
        case .saveAsNewProfile: newProfileNamingRequested = true
        }
    }
}
