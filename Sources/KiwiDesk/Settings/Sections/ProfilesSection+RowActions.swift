import KiwiDeskCore
import SwiftUI

/// Profile row action controls (Load, Delete, Make Default, #515, #789, #816).
extension ProfilesSection {
    // Load and Delete confirm discard when edits are pending (#515).
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
        // Focus return target on dismissal (#816).
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
                // Determine focus target before mutation (#816).
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

    /// Inline text link to set profile as default.
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
