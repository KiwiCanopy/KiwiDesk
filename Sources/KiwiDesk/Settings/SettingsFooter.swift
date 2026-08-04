import KiwiDeskCore
import SwiftUI

/// The stable three-verb footer (#68 §3.12): the same slots in
/// every mode — Revert, "Save a Copy As…", and a primary Save
/// (⌘S), clustered at the trailing edge. The banner above
/// names the edit target authoritatively; a destination
/// caption beside Save duplicated it and was dropped as
/// confusing. What each verb does per mode:
///
/// - Live w/ active profile: Save = update the profile (+
///   monitor-set refresh); Copy = snapshot into a new profile.
/// - Stored-profile edit: Save = write that profile's JSON
///   without switching the layout; Copy = duplicate with the
///   pending edits (#82; enabled with no edits — a plain
///   duplicate is legitimate).
/// - Live w/ no profile (Standard/transient): the primary
///   becomes "Save as New Profile…" — there is no target yet.
/// - Raw-Lua editing: Save writes init.lua verbatim; the
///   Adopt action lives in the editor's own banner (§3.12),
///   not here.
struct SettingsFooter: View {
    @ObservedObject var model: SettingsModel
    @State private var namingNewProfile = false
    @State private var newProfileName = ""
    @State private var namingProfileCopy = false
    @State private var profileCopyName = ""

    var body: some View {
        HStack(spacing: 8) {
            if model.isDirty {
                Label(
                    L(
                        "footer.unsaved_changes",
                        "Unsaved changes"
                    ),
                    systemImage: "pencil.circle"
                )
                .font(.caption)
                .foregroundStyle(SettingsTheme.warningInk)
            }
            if model.primarySaveAction == .saveGlobalsOnly {
                // Names what is EXCLUDED, not the six fields it
                // writes — one sentence beats a field list, and
                // the reader already has the paused banner above
                // for the why (#516, ui-designer).
                Text(pausedScopeCaption)
                    .font(.caption2)
                    .foregroundStyle(SettingsTheme.ink2)
            }
            if let drift = model.layoutDrift {
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        L(
                            "footer.save.adopts_layout",
                            "Save also adopts the session layout (%1$@).",
                            drift.live.displayName
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(SettingsTheme.ink2)
                    Text(
                        L(
                            "footer.revert.restores_layout",
                            "Revert also restores the profile "
                                + "layout (%1$@).",
                            drift.saved.displayName
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(SettingsTheme.ink2)
                }
            }
            Spacer()
            Button(L("footer.revert", "Revert Changes")) {
                model.revert()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(!(model.isDirty || model.hasLayoutDrift))
            copySlot
            primarySlot
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        // Card fill, like the header it bookends. Without it the
        // bar inherited the page and read as a third grey between
        // the two — the hairline above (`SettingsView.chrome`) is
        // what separates them now.
        .background(SettingsTheme.card)
        .alert(
            L(
                "footer.save_as_new.title",
                "Save as new profile"
            ),
            isPresented: $namingNewProfile
        ) {
            TextField(
                L("footer.profile_name", "Profile name"),
                text: $newProfileName
            )
            Button(L("footer.save", "Save")) {
                model.saveAsNewProfile(named: newProfileName)
                newProfileName = ""
            }
            .disabled(newProfileName.trimmed.isEmpty)
            Button(L("footer.cancel", "Cancel"), role: .cancel) {
                newProfileName = ""
            }
        } message: {
            Text(saveAsNewMessage)
        }
        .alert(
            L("footer.save_copy_as.title", "Save a copy as"),
            isPresented: $namingProfileCopy
        ) {
            TextField(
                L("footer.profile_name", "Profile name"),
                text: $profileCopyName
            )
            Button(L("footer.save_copy", "Save copy")) {
                model.saveEditedProfileCopy(
                    named: profileCopyName
                )
                profileCopyName = ""
            }
            .disabled(profileCopyName.trimmed.isEmpty)
            Button(L("footer.cancel", "Cancel"), role: .cancel) {
                profileCopyName = ""
            }
        } message: {
            Text(saveCopyMessage)
        }
    }

    private var saveAsNewMessage: String {
        L(
            "footer.save_as_new.message",
            "The new profile carries the current tiling "
                + "and the connected monitor set."
        )
    }

    private var saveCopyMessage: String {
        L(
            "footer.save_copy_as.message",
            "Duplicates \u{201C}%1$@\u{201D} with your "
                + "pending edits — monitor sets and shortcut "
                + "overrides included. The copy becomes the "
                + "edit target; the running layout is not "
                + "changed.",
            model.editingProfile ?? ""
        )
    }

    // MARK: - Secondary slot: Save a Copy As…

    /// Hidden in the raw-Lua mode (no profile is being
    /// edited) and in the no-profile live mode (it would
    /// duplicate the primary).
    @ViewBuilder private var copySlot: some View {
        if model.editingLua {
            EmptyView()
        } else if model.editingStoredProfile {
            Button(saveCopyAsLabel) {
                namingProfileCopy = true
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        } else if model.activeProfile != nil {
            // Live active profile → a copy captures the live
            // monitor set, so it is blocked while paused (#335).
            Button(saveCopyAsLabel) {
                namingNewProfile = true
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(model.profileSaveBlockedReason != nil)
            .help(model.profileSaveBlockedReason ?? "")
        }
    }

    private var pausedScopeCaption: String {
        L(
            "footer.save.globals_only",
            "Layout and monitors stay paused; Save covers "
                + "everything else."
        )
    }

    private var saveCopyAsLabel: String {
        L("footer.save_a_copy_as", "Save a Copy As…")
    }

    // MARK: - Primary slot: Save (⌘S)

    @ViewBuilder private var primarySlot: some View {
        let save = L("footer.save", "Save")
        switch model.primarySaveAction {
        case .saveLua:
            Button(save) { model.saveLuaSource() }
                .keyboardShortcut("s")
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!model.isDirty)
        case .updateStoredProfile:
            Button(save) { model.saveEditedProfile() }
                .keyboardShortcut("s")
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!model.isDirty)
        case .updateActiveProfile:
            // Update refreshes the live monitor set, so it is
            // blocked while paused (#335).
            Button(save) { model.updateActiveProfile() }
                .keyboardShortcut("s")
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
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
            // beside the footer, not the label (#516).
            Button(save) { model.saveGlobalsWhilePaused() }
                .keyboardShortcut("s")
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
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
            .controlSize(.regular)
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
    private func prefillNewProfileName() {
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
