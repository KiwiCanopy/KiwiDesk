import KiwiDeskCore
import SwiftUI

/// The floating save pill (#678 redesign spec): "N
/// unsaved changes to Desk | Revert · Save a copy… · Save",
/// dark chrome floating over the content column. It exists
/// only while there is something to act on — a dirty draft,
/// profile-level edits, or layout drift — and disappears at
/// zero (`GreyOutHidingTests` carries this file's exemption
/// from grey-don't-hide). Owner 2026-08-09 overturned the
/// earlier docked-footer ruling on sight; the planned
/// responsive pass will dock the pill back into a real footer
/// bar below 900 pt, as its one change of kind.
///
/// The verbs keep the docked footer's exact semantics per mode
/// (#68 §3.12):
/// - Live w/ active profile: Save = update the profile (+
///   monitor-set refresh); Copy = snapshot into a new profile.
/// - Stored-profile edit: Save = write that profile's JSON
///   without switching the layout; Copy = duplicate with the
///   pending edits (#82). A CLEAN duplicate no longer has a
///   footer to live in — that offer stays reachable from the
///   Profiles area, which is its home.
/// - Live w/ no profile: the primary becomes "Save as New
///   Profile…".
/// - Raw-Lua editing: Save writes init.lua verbatim.
struct SettingsFooter: View {
    @ObservedObject var model: SettingsModel
    @State var namingNewProfile = false
    @State var newProfileName = ""
    @State var namingProfileCopy = false
    @State var profileCopyName = ""
    /// The unsaved-changes popover — turn 9's third view of the
    /// draft, moved here from the header chip (owner
    /// 2026-08-10): the pill already narrates the draft, so the
    /// count it carries is the one that opens the list. View
    /// state: closing the window closes it, and nothing else
    /// needs to open it.
    @State var unsavedPopoverShown = false

    /// Anything that gives a verb meaning. The
    /// `.saveAsNewProfile` creation offer on a fully clean
    /// setup deliberately does NOT summon the pill — creation
    /// lives in Profiles; the pill narrates a draft.
    private var hasWork: Bool {
        model.isDirty || model.profileDirty
            || model.hasLayoutDrift
    }

    var body: some View {
        Group {
            if hasWork {
                pill
                    .transition(
                        .opacity.combined(
                            with: .move(edge: .bottom)
                        )
                    )
            }
        }
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

    private var pill: some View {
        HStack(spacing: 12) {
            leadingReadout
            Text(verbatim: "|")
                .foregroundStyle(
                    SettingsTheme.savePillInk.opacity(0.4)
                )
            Button(L("footer.revert", "Revert")) {
                model.revert()
            }
            .buttonStyle(.plain)
            .foregroundStyle(
                SettingsTheme.savePillInk.opacity(0.8)
            )
            .disabled(!(model.isDirty || model.hasLayoutDrift))
            copySlot
            primarySlot
        }
        .font(.callout)
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(
                cornerRadius: SettingsTheme.cardRadius
            )
            .fill(SettingsTheme.savePill)
            .shadow(
                color: SettingsTheme.savePill.opacity(0.45),
                radius: 17,
                y: 7
            )
        )
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
}
