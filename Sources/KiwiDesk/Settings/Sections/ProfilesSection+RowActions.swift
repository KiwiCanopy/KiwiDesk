import KiwiDeskCore
import SwiftUI

/// A saved-profile row's three action controls, split from
/// `ProfilesSection` for the §2.1 file ceiling (#789 pushed it to
/// 343 of 350).
///
/// They ride together because they are one decision each way: two
/// of them end in `reload()` and so are gated behind the discard
/// confirmation (#515), and the third is the quiet inline link
/// that must NOT look like their peer. `profileRow` composes
/// them; nothing else calls them.
///
/// `internal` rather than `private`, which is what a split costs:
/// a `private` member is visible only inside its own file, so the
/// row that composes these could no longer see them. The same
/// trade `shownProfile` already states for the rename affordance.
extension ProfilesSection {
    // Load / Delete both end in `reload()`, which re-seeds from
    // disk and clears the dirty flag, so both drop staged edits —
    // gated like the edit-target menu (#515).
    func loadButton(
        _ summary: ProfileSummary
    ) -> some View {
        Button(L("profiles.load", "Load")) {
            model.discardingEdits(
                message: L(
                    "discard.load_profile.message",
                    "Loading a profile replaces the edits "
                        + "you haven't saved."
                ),
                confirmLabel: L(
                    "discard.load_profile.confirm",
                    "Discard & load"
                )
            ) { model.loadProfile(named: summary.name) }
        }
        .settingsActionButton()
        .controlSize(.large)
        // The row's return destination (#816). Load is the
        // always-drawn, non-destructive one: "make default" is
        // conditional on the row not already being default, the
        // name opens a rename, and Delete would put a
        // destructive action under the next keypress.
        .focused($returningRow, equals: summary.name)
        .help(
            summary.matchesLive
                ? ""
                : L(
                    "profiles.other_monitors.help",
                    "Saved for other monitors — loads "
                        + "with unsaved-changes state."
                )
        )
    }

    func deleteButton(_ name: String) -> some View {
        Button {
            model.discardingEdits(
                message: L(
                    "discard.delete_profile.message",
                    "Deleting reloads the dashboard, "
                        + "dropping the edits you haven't "
                        + "saved."
                ),
                confirmLabel: L(
                    "discard.delete_profile.confirm",
                    "Discard & delete"
                )
            ) {
                // Read BEFORE the mutation (#816): afterwards
                // the list names whichever row slid into the
                // gap, which is right by accident and wrong at
                // the end of a list.
                let neighbour = neighbourAfterDeleting(name)
                model.deleteProfile(named: name)
                returningRow = neighbour
            }
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .iconButtonAffordance(
            L("profiles.delete.help", "Delete profile")
        )
    }

    /// "make default" is a quiet inline link — underlined
    /// lowercase text rather than a button; hover lifts the
    /// color and shows the pointing-hand cursor.
    func makeDefaultLink(
        _ name: String
    ) -> some View {
        Button {
            model.makeDefault(named: name)
        } label: {
            Text(L("profiles.make_default", "make default"))
                .underline()
        }
        .buttonStyle(.plain)
        .font(.caption)
        .linkHover()
    }
}
