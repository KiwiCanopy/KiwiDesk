import KiwiDeskCore
import SwiftUI

/// The pill's verb slots and the naming-sheet plumbing — split
/// from `SettingsFooter.swift` at the §2.1 hard ceiling. The
/// slot semantics (#68 §3.12) are documented on the struct.
extension SettingsFooter {
    // MARK: - Secondary slot: Save a copy…

    /// Hidden in the raw-Lua mode (no profile is being
    /// edited) and in the no-profile live mode (it would
    /// duplicate the primary).
    @ViewBuilder var copySlot: some View {
        if model.editingLua {
            EmptyView()
        } else if model.editingStoredProfile {
            Button(saveCopyAsLabel) {
                namingProfileCopy = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(
                SettingsTheme.savePillInk.opacity(0.8)
            )
        } else if model.activeProfile != nil {
            // Live active profile → a copy captures the live
            // monitor set, so it is blocked while paused (#335).
            Button(saveCopyAsLabel) {
                namingNewProfile = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(
                SettingsTheme.savePillInk.opacity(0.8)
            )
            .disabled(model.profileSaveBlockedReason != nil)
            .help(model.profileSaveBlockedReason ?? "")
        }
    }

    var pausedScopeCaption: String {
        L(
            "footer.save.globals_only",
            "Layout and screens stay paused; %1$@ covers "
                + "everything else.",
            L("footer.save", "Save")
        )
    }

    var saveCopyAsLabel: String {
        L("footer.save_a_copy_as", "Save as new profile…")
    }

    // MARK: - Primary slot: Save (⌘S)

    @ViewBuilder var primarySlot: some View {
        let save = L("footer.save", "Save")
        switch model.primarySaveAction {
        case .saveLua:
            Button(save) { model.saveLuaSource() }
                .keyboardShortcut("s")
                .buttonStyle(.borderedProminent)
                .disabled(!model.isDirty)
        case .updateStoredProfile:
            Button(save) { model.saveEditedProfile() }
                .keyboardShortcut("s")
                .buttonStyle(.borderedProminent)
                .disabled(!model.isDirty)
        case .updateActiveProfile:
            // Update refreshes the live monitor set, so it is
            // blocked while paused (#335).
            Button(save) { model.updateActiveProfile() }
                .keyboardShortcut("s")
                .buttonStyle(.borderedProminent)
                .disabled(
                    model.profileSaveBlockedReason != nil
                        || !model.updateEnabled
                        || !(model.isDirty
                            || model.profileDirty
                            || model.hasLayoutDrift)
                )
                .help(
                    model.profileSaveBlockedReason
                        ?? model.updateHint ?? ""
                )
        case .saveGlobalsOnly:
            // Accessibility is off, so no profile may capture
            // the empty monitor set — but a global changed, and
            // globals carry no monitor set. Plain "Save", like
            // its two profile siblings: scope rides the caption
            // in the pill's readout, not the label (#516).
            Button(save) { model.saveGlobalsWhilePaused() }
                .keyboardShortcut("s")
                .buttonStyle(.borderedProminent)
                .disabled(!model.isDirty)
        case .saveAsNewProfile:
            // No profile yet — the create action takes the
            // primary slot; it captures the live monitor set,
            // so it is blocked while paused (#335).
            Button(
                L(
                    "footer.save_as_new_profile",
                    "Save as New Profile…"
                )
            ) {
                prefillNewProfileName()
                namingNewProfile = true
            }
            .keyboardShortcut("s")
            .buttonStyle(.borderedProminent)
            .disabled(model.profileSaveBlockedReason != nil)
            .help(model.profileSaveBlockedReason ?? "")
        }
    }

    /// Pre-fills the first-save naming sheet (ui-designer
    /// 2026-07-19) so confirming is one Enter instead of
    /// composing a name cold. Uniqued against existing
    /// profiles for the edge where profiles exist but none is
    /// active; a name the user already typed is never
    /// overwritten.
    func prefillNewProfileName() {
        guard newProfileName.trimmed.isEmpty else { return }
        let base = L(
            "footer.default_profile_name",
            "My Setup"
        )
        // Availability via the facade query, not a local copy
        // of the collision rule — canRename holds the one
        // sanctioned mirror (review 2026-07); this is the
        // second consumer that decision reserved for the
        // query. Case-insensitivity (APFS) rides along.
        var name = base
        var suffix = 2
        while !model.core.isProfileNameFree(name) {
            name = "\(base) \(suffix)"
            suffix += 1
        }
        newProfileName = name
    }
}
