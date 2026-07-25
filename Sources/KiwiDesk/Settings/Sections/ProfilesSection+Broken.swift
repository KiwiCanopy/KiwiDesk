import KiwiDeskCore
import SwiftUI

/// The unreadable-profile rows for App ▸ Profiles (#246). A
/// profile whose JSON won't decode can't yield a `ProfileSummary`
/// (no count, no monitor sets), so it can't slot into a screen-
/// count group — but hiding it strands a broken file with no way
/// to clear it. Grey-don't-hide (#171): one flat group under the
/// saved profiles, each row dimmed, warning-marked, and carrying
/// the one action that still works — Delete. Reveal lives in the
/// Config Issues panel, which the same badge already surfaces.
extension ProfilesSection {
    @ViewBuilder var brokenGroup: some View {
        SettingsGroupHeader(
            L("profiles.broken.title", "Couldn't load")
        )
        .padding(.top, 4)
        ForEach(model.brokenProfiles, id: \.self) { name in
            brokenRow(name)
        }
    }

    private func brokenRow(_ name: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .foregroundStyle(.secondary)
                Text(
                    L(
                        "profiles.broken.cant_load",
                        "Can't load — saved by another version "
                            + "or edited by hand."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            // Same `reload()` tail as the healthy-row Delete, so
            // the same discard gate (#515). Found by the
            // structural guard, not by the audit — which is the
            // argument for having the guard.
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
                ) { model.deleteProfile(named: name) }
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
