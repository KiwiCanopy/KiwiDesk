import KiwiDeskCore
import SwiftUI

/// The stable three-verb footer (#68 §3.12): the same slots in
/// every mode — Revert, "Save a Copy As…", and a primary Save
/// (⌘S) whose destination is named in a caption beside it
/// instead of inside the label. What each verb does per mode:
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
                    "Unsaved changes",
                    systemImage: "pencil.circle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
            Spacer()
            Button("Revert") { model.revert() }
                .disabled(!model.isDirty)
            copySlot
            primarySlot
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .alert(
            "Save as new profile",
            isPresented: $namingNewProfile
        ) {
            TextField("Profile name", text: $newProfileName)
            Button("Save") {
                model.saveAsNewProfile(named: newProfileName)
                newProfileName = ""
            }
            .disabled(newProfileName.trimmed.isEmpty)
            Button("Cancel", role: .cancel) {
                newProfileName = ""
            }
        } message: {
            Text(
                "The new profile carries the current tiling "
                    + "and the connected monitor set."
            )
        }
        .alert(
            "Save a copy as",
            isPresented: $namingProfileCopy
        ) {
            TextField("Profile name", text: $profileCopyName)
            Button("Save copy") {
                model.saveEditedProfileCopy(
                    named: profileCopyName
                )
                profileCopyName = ""
            }
            .disabled(profileCopyName.trimmed.isEmpty)
            Button("Cancel", role: .cancel) {
                profileCopyName = ""
            }
        } message: {
            Text(
                "Duplicates \u{201C}"
                    + (model.editingProfile ?? "")
                    + "\u{201D} with your pending edits — "
                    + "monitor sets and shortcut overrides "
                    + "included. The copy becomes the edit "
                    + "target; the running layout is not "
                    + "changed."
            )
        }
    }

    // MARK: - Secondary slot: Save a Copy As…

    /// Hidden in the raw-Lua mode (no profile is being
    /// edited) and in the no-profile live mode (it would
    /// duplicate the primary).
    @ViewBuilder private var copySlot: some View {
        if model.editingLua {
            EmptyView()
        } else if model.editingStoredProfile {
            Button("Save a Copy As…") {
                namingProfileCopy = true
            }
        } else if model.activeProfile != nil {
            Button("Save a Copy As…") {
                namingNewProfile = true
            }
        }
    }

    // MARK: - Primary slot: Save (⌘S)

    @ViewBuilder private var primarySlot: some View {
        if model.editingLua {
            Button("Save") { model.saveLuaSource() }
                .keyboardShortcut("s")
                .buttonStyle(.borderedProminent)
                .disabled(!model.isDirty)
        } else if model.editingStoredProfile {
            saveTarget(model.editingProfile ?? "")
            Button("Save") { model.saveEditedProfile() }
                .keyboardShortcut("s")
                .buttonStyle(.borderedProminent)
                .disabled(!model.isDirty)
        } else if let name = model.activeProfile {
            saveTarget(name)
            Button("Save") { model.updateActiveProfile() }
                .keyboardShortcut("s")
                .buttonStyle(.borderedProminent)
                .disabled(
                    !model.updateEnabled
                        || !(model.isDirty
                            || model.profileDirty)
                )
                .help(model.updateHint ?? "")
        } else {
            // No profile yet — the create action takes the
            // primary slot.
            Button("Save as New Profile…") {
                namingNewProfile = true
            }
            .keyboardShortcut("s")
            .buttonStyle(.borderedProminent)
        }
    }

    /// The destination caption beside the primary Save: the
    /// banner names the edit target authoritatively; this
    /// keeps the button label stable across modes (§3.12).
    private func saveTarget(_ name: String) -> some View {
        Text("→ \u{201C}\(name)\u{201D}")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: 180)
    }
}
