import KiwiDeskCore
import SwiftUI

/// The unreadable-profile rows for App ▸ Profiles (#246). A
/// profile whose JSON won't decode can't yield a `ProfileSummary`
/// (no count, no monitor sets), so it can't slot into a screen-
/// count group — but hiding it strands a broken file with no way
/// to clear it, and a profile that vanishes from the list reads
/// as data loss. Grey-don't-hide (#171): one flat group under the
/// saved profiles, each row dimmed, warning-marked, and carrying
/// the two actions that still work — Reveal and Delete.
///
/// The caption names WHICH failure it was (#678 Phase 4 pass 9,
/// turn 18), because that is what decides whether Reveal is worth
/// clicking: malformed JSON shows its own damage in an editor, a
/// shape mismatch does not. It comes from `ProfileBrokenText`,
/// shared with the Config Issues panel — the two surfaces used to
/// carry two hand-written sentences about one file.
///
/// Deliberately absent from the census, Reveal included, and this
/// group has been since it shipped: a row that exists only while a
/// file is broken cannot be a search result without stranding
/// whoever picks it on a healthy install — the same reason the
/// per-space `[space]` keys are excluded (#678 Phase 4 pass 6).
/// The route in is the config-error badge, which is present
/// exactly when these rows are.
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
                model.revealProfile(named: name)
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .iconButtonAffordance(
                L("profiles.broken.reveal", "Reveal file in Finder")
            )
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
