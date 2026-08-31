import KiwiDeskCore
import SwiftUI

/// Unreadable profile rows in App ▸ Profiles
/// (`ProfileBrokenText`, #171, #246).
extension ProfilesSection {
    @ViewBuilder var brokenGroup: some View {
        SettingsGroupHeader(
            L("profiles.broken.title", "Couldn't load")
        )
        .padding(.top, 4)
        ForEach(model.brokenProfiles) { broken in
            brokenRow(broken)
        }
    }

    /// Focus neighbor within broken profile list after deletion
    /// (`DeletionFocus`, #816).
    func neighbourBrokenAfter(_ name: String) -> String? {
        DeletionFocus.neighbour(
            after: name,
            in: model.brokenProfiles.map(\.name)
        )
    }

    private func brokenRow(_ broken: BrokenProfile) -> some View {
        let name = broken.name
        return HStack(alignment: .firstTextBaseline) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(SettingsTheme.warningInk)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .foregroundStyle(.secondary)
                Text(ProfileBrokenText.message(for: broken.cause))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.onRevealProfile(name)
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .focused($returningRow, equals: name)
            .iconButtonAffordance(
                L("config_issues.reveal", "Reveal in Finder")
            )
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
                    let neighbour = neighbourBrokenAfter(name)
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
    }
}
