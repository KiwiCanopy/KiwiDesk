import Foundation
import KiwiDeskCore

/// Which Save verb the footer offers, and why — the single
/// classifier every affordance that points at Save reads, split
/// from `SettingsModel.swift` for the file ceiling.
extension SettingsModel {
    /// Which primary Save verb the footer currently offers. The
    /// single source of the edit-context classification so any
    /// affordance that points the user at Save (the footer's own
    /// primary slot, the Fit-Gaps status) reads it here instead
    /// of re-deriving the branch — a second copy silently omitted
    /// the raw-Lua case and hard-coded the button labels.
    enum PrimarySaveAction {
        /// Save (⌘S) writes init.lua verbatim.
        case saveLua
        /// Save (⌘S) writes the stored profile; applies on load.
        case updateStoredProfile
        /// Save (⌘S) updates the active profile: apply + persist.
        case updateActiveProfile
        /// No target yet — Save as New Profile… creates one.
        case saveAsNewProfile
        /// Accessibility is off, so no profile may capture the
        /// (empty) monitor set — but a global setting changed,
        /// and globals have no monitor dependency. Save (⌘S)
        /// writes `gui.json` only (#516).
        case saveGlobalsOnly
    }

    var primarySaveAction: PrimarySaveAction {
        if editingLua { return .saveLua }
        if editingStoredProfile { return .updateStoredProfile }
        // Ahead of both profile verbs, and only ahead of them:
        // .saveLua and .updateStoredProfile write no monitor set
        // either, so they were never blocked and must not be
        // rerouted (#516).
        // `savedSidecar` is nil exactly when the config is NOT
        // GUI-managed, and `globalsChanged` reports true for an
        // unknown baseline — so without this guard a Lua-owned
        // config offers the globals Save unconditionally, with
        // no edit pending, and writing it would create gui.json
        // and seize ownership from init.lua outside the one
        // sanctioned adopt path (AGENTS §5). An unknown baseline
        // is not evidence of a pending global edit.
        if permissionPaused, savedSidecar != nil, globalsChanged {
            return .saveGlobalsOnly
        }
        if activeProfile != nil { return .updateActiveProfile }
        return .saveAsNewProfile
    }
}
