import KiwiDeskCore
import SwiftUI

/// Profiles section: lists saved profiles, loading defaults, and presets
/// (#36, #53, #68).
struct ProfilesSection: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @ObservedObject var model: SettingsModel
    /// Profile whose rename popover is presented (#843).
    @State var renameRequest: NameEditRequest?
    /// Keyboard focus return anchor after row deletion (#816).
    @FocusState var returningRow: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(areaCaption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.profileSummaries.isEmpty {
                    // Presets lead when no user profile is saved (#53).
                    PresetsSection(model: model)
                    profileSection
                    whichProfileLoads
                    DesktopsGroup(model: model)
                } else {
                    profileSection
                    whichProfileLoads
                    DesktopsGroup(model: model)
                    PresetsSection(model: model)
                }
            }
            .animation(
                reduceMotion ? nil : .default,
                value: model.profileSummaries.isEmpty
            )
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }

    private var areaCaption: String {
        L(
            "profiles.area.caption",
            "A profile is your whole setup, remembered per "
                + "display arrangement."
        )
    }

    private var profileSection: some View {
        SettingsSection(
            SettingsCatalog.profiles.savedProfiles,
            caption: L(
                "profiles.saved.caption",
                "The one matching your displays loads "
                    + "automatically."
            )
        ) {
            if model.profileSummaries.isEmpty
                && model.brokenProfiles.isEmpty
            {
                Text(noProfilesCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(orderedSummaries) { summary in
                profileRow(summary)
            }
            if let note = currentSetupNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            if !model.brokenProfiles.isEmpty {
                brokenGroup
            }
        }
    }

    private var noProfilesCaption: String {
        L(
            "profiles.saved.empty",
            "No profiles saved yet — a built-in layout "
                + "resolves until you save one."
        )
    }

    /// Note describing current setup destination (#818).
    private var currentSetupNote: String? {
        guard !model.editingStoredProfile,
            let active = model.activeProfile
        else { return nil }
        return L(
            "profiles.current_setup_note",
            "Your current setup is saved into %1$@. To keep it "
                + "separately, use \u{201C}%2$@\u{201D} in the "
                + "bar below.",
            active,
            L("footer.save_a_copy_as", "Save as new profile…")
        )
    }

    /// Saved profile summaries in display order.
    private var orderedSummaries: [ProfileSummary] {
        ProfilesFamilyRows.orderedProfiles(
            model.profileSummaries
        )
    }

    /// Next focus target when deleting `name` (`DeletionFocus`).
    func neighbourAfterDeleting(_ name: String) -> String? {
        DeletionFocus.neighbour(
            after: name,
            in: orderedSummaries.map(\.name)
        )
    }

    private func profileRow(
        _ summary: ProfileSummary
    ) -> some View {
        HStack(alignment: .center) {
            // Screen count icon (#789).
            screenPicture(summary)
            VStack(alignment: .leading, spacing: 3) {
                rowTitle(summary)
                Text(subtitle(summary))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(monitorTooltip(summary))
            }
            Spacer()
            if !summary.isDefault {
                makeDefaultLink(summary.name)
            }
            loadButton(summary)
            deleteButton(summary.name)
        }
    }

    /// Leading screen count diagram (#789).
    private func screenPicture(
        _ summary: ProfileSummary
    ) -> some View {
        ProfileScreenPips(
            count: summary.count,
            openingModes: summary.openingModes,
            reservedSlots: reservedScreenSlots
        )
    }

    /// Slot count reserved for monitor icons across rows.
    private var reservedScreenSlots: Int {
        ProfileScreenPips.reservedSlots(
            forScreenCounts: orderedSummaries.map(\.count)
        )
    }

    private func rowTitle(
        _ summary: ProfileSummary
    ) -> some View {
        HStack(spacing: 6) {
            Text(summary.name)
                .onTapGesture(count: 2) {
                    beginRename(summary.name)
                }
            renameButton(summary.name)
            if summary.name == model.activeProfile {
                BadgeChip(
                    label: L("profiles.badge.active", "active")
                )
            }
            if summary.isDefault {
                BadgeChip(
                    label: L("profiles.badge.default", "default")
                )
                duplicateDefaultWarning(summary)
            }
        }
    }

    /// Warning shown when multiple profiles share a default flag for count.
    @ViewBuilder private func duplicateDefaultWarning(
        _ summary: ProfileSummary
    ) -> some View {
        if model.duplicateDefaultCounts.contains(summary.count) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(SettingsTheme.warningInk)
                .font(.caption)
                .help(
                    L(
                        "profiles.duplicate_default.help",
                        "Several profiles of this count "
                            + "are marked default; the "
                            + "alphabetically first wins."
                    )
                )
        }
    }
}
