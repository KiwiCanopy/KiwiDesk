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
            summary.matchesConnectedCount
                ? ""
                : L(
                    "profiles.other_count.help",
                    "Saved for a different number of screens — "
                        + "loads with unsaved changes."
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

    /// Inline text link to set profile as default. Greyed on a
    /// dormant row, which cannot load as a fallback (#1530); the
    /// row's own caption says why.
    func makeDefaultLink(
        _ summary: ProfileSummary
    ) -> some View {
        Button {
            model.makeDefault(named: summary.name)
        } label: {
            Text(makeDefaultTitle(summary.count))
                .underline()
        }
        .buttonStyle(.plain)
        .font(.caption)
        .linkHover()
        .disabled(summary.isDormant)
    }

    /// A default is per screen count, so the link names its count
    /// — the number last, as the badge beside it does (owner,
    /// 2026-09-24).
    func makeDefaultTitle(_ count: Int) -> String {
        count == 1
            ? L("profiles.make_default.one", "make default for 1 screen")
            : L(
                "profiles.make_default.many",
                "make default for %1$d screens",
                count
            )
    }
}
