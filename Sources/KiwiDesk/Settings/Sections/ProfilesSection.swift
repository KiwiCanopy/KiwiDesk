import KiwiDeskCore
import SwiftUI

/// Profiles section: lists saved profiles, loading defaults, and
/// presets (#36, #53, #68; rebuilt in #678 Phase 3 turn 13a).
struct ProfilesSection: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @ObservedObject var model: SettingsModel
    /// Profile whose rename popover is presented (#843).
    @State var renameRequest: NameEditRequest?
    /// Profile whose full screen-setup list is open (#1530).
    @State var setupListRequest: ScreenSetupListRequest?
    /// Keyboard focus return anchor after row deletion (#816).
    @FocusState var returningRow: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(areaCaption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                // What loads right now leads: the page's live answer,
                // above the cards that decide it (owner, #1609).
                whichProfileLoads
                if model.profileSummaries.isEmpty {
                    // Presets lead when no user profile is saved (#53).
                    PresetsSection(model: model)
                    profileSection
                    DesktopsGroup(model: model)
                } else {
                    profileSection
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
                "A profile loads on the screen setups it holds, "
                    + "unless a Desktop is bound to another."
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
            if let note = oneOwnerNote {
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

    /// "a built-in layout", not "the built-in Standard": no
    /// layout is NAMED Standard, and two nouns for one thing on
    /// one page sends a translator two ways.
    private var noProfilesCaption: String {
        L(
            "profiles.saved.empty",
            "No profiles saved yet — a built-in layout "
                + "resolves until you save one."
        )
    }

    /// The one rule the badge lines cannot show: moving a screen
    /// setup takes it from its holder (#1530, owner 2026-09-23).
    private var oneOwnerNote: String? {
        guard !model.profileSummaries.isEmpty else { return nil }
        return L(
            "profiles.sets.one_owner_note",
            "Each screen setup belongs to one profile at a time. Moving "
                + "it to another profile removes it from the current one."
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
        // Centred: the counters belong to the whole text block
        // (owner eye-confirm, 2026-08-16; #1624).
        HStack(alignment: .center) {
            ProfileCounters(
                screens: summary.count,
                spaces: summary.spaceCount,
                help: subtitle(summary)
            )
            VStack(alignment: .leading, spacing: 3) {
                rowTitle(summary)
                screenSetupsLine(summary)
            }
            Spacer()
            if !summary.isDefault {
                makeDefaultLink(summary)
            }
            loadButton(summary)
            deleteButton(summary.name)
        }
    }

    private func rowTitle(
        _ summary: ProfileSummary
    ) -> some View {
        HStack(spacing: 6) {
            // One line, never wrapping under its badges; in a narrow
            // window the name shortens rather than the row overflowing.
            Text(summary.name)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
                // The counters' tooltip, read after the name (#1624).
                .accessibilityValue(subtitle(summary))
                .onTapGesture(count: 2) {
                    beginRename(summary.name)
                }
            renameButton(summary.name)
            if summary.name == model.activeProfile {
                BadgeChip(
                    label: L("profiles.badge.loaded", "loaded")
                )
            }
            if summary.isDefault {
                BadgeChip(label: defaultBadge(summary.count))
                duplicateDefaultWarning(summary)
            }
        }
    }

    /// A default is per screen count, so the badge says which
    /// (#1530) — the count last, behind a label (localization.md).
    private func defaultBadge(_ count: Int) -> String {
        L("profiles.badge.default_for", "default · screens: %1$d", count)
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
