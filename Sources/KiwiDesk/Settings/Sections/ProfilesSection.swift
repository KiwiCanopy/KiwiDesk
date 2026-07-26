import KiwiDeskCore
import SwiftUI

/// Whole App ▸ Profiles (#36/#53/#68 §3.2): the saved-profiles
/// list grouped by screen count, the native-Space bindings,
/// and the built-in Presets — "which profile applies
/// where/when" in one place. The Desktop bindings always ride
/// directly beneath the saved profiles they reference. Presets
/// lead only while no profile is saved yet (bootstrap, so
/// first launch is never barren); once one exists, the user's
/// own content takes the top and the full preset list closes
/// the tab.
struct ProfilesSection: View {
    @ObservedObject var model: SettingsModel
    /// The profile whose rename popover is open, if any.
    /// `internal`, not `private`: the rename affordance that
    /// owns this state lives in `ProfilesSection+Rename.swift`
    /// (file ceiling), and `@State` cannot move to an extension.
    @State var renaming: String?
    @State var renameDraft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if model.profileSummaries.isEmpty {
                    PresetsSection(model: model)
                    profileSection
                    nativeSpaces
                } else {
                    profileSection
                    nativeSpaces
                    PresetsSection(model: model)
                }
            }
            .animation(
                .default,
                value: model.profileSummaries.isEmpty
            )
            .padding(16)
        }
    }

    /// "Which profile applies where/when" lives together
    /// (#68 §3.2): native-Space bindings are global — only
    /// offered in live editing.
    @ViewBuilder private var nativeSpaces: some View {
        // Greyed, not hidden (#171/#520). The bindings are
        // global and a stored profile may never override what
        // SELECTS it (AGENTS §5), so they are correctly not
        // editable here — but hiding them meant a user editing a
        // profile could not even READ which Desktop maps to
        // what, which is exactly the context that decision needs.
        // Gate passed IN, not wrapped around (#527): the group
        // keeps its section header — and its `?` anchor — live.
        NativeSpacesGroup(
            model: model,
            gatedOff: model.editingStoredProfile,
            gateHelp: L(
                "profiles.native_spaces.live_only",
                "Desktop bindings are global — switch to "
                    + "Live to change them."
            )
        )
    }

    // MARK: - Saved profiles (#36)

    private var profileSection: some View {
        SettingsSection(
            L("profiles.saved.title", "Saved profiles")
        ) {
            if model.profileSummaries.isEmpty
                && model.brokenProfiles.isEmpty
            {
                Text(noProfilesCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(profileCounts, id: \.self) { count in
                countGroupHeader(count)
                ForEach(summaries(for: count)) { summary in
                    profileRow(summary)
                }
            }
            if !model.brokenProfiles.isEmpty {
                brokenGroup
            }
        }
    }

    private var noProfilesCaption: String {
        L(
            "profiles.saved.empty",
            "No profiles saved yet — the built-in "
                + "Standard resolves until you save "
                + "one."
        )
    }

    /// The live count's group sorts on top; the rest ascend.
    private var profileCounts: [Int] {
        let counts = Set(model.profileSummaries.map(\.count))
        let live = model.displays.count
        return counts.sorted {
            ($0 == live ? 0 : 1, $0) < ($1 == live ? 0 : 1, $1)
        }
    }

    private func summaries(
        for count: Int
    ) -> [ProfileSummary] {
        model.profileSummaries.filter { $0.count == count }
    }

    private func countGroupHeader(
        _ count: Int
    ) -> some View {
        HStack(spacing: 6) {
            // A navigational grouping header, not a hint —
            // uses the shared group-header style, one step above
            // a section's headline, instead of caption text.
            SettingsGroupHeader(
                count == 1
                    ? L("profiles.screens.one", "1 screen")
                    : L(
                        "profiles.screens.many",
                        "%1$d screens",
                        count
                    )
            )
            if count == model.displays.count {
                BadgeChip(
                    label: L(
                        "profiles.badge.connected",
                        "connected"
                    )
                )
            }
            if model.duplicateDefaultCounts.contains(count) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
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
        .padding(.top, 4)
    }

    private func profileRow(
        _ summary: ProfileSummary
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: "square.stack.3d.up")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(summary.name)
                        // Bonus discovery path (low-risk): a
                        // double-click on the name opens the
                        // same rename popover as the pencil,
                        // which stays the primary visible cue.
                        .onTapGesture(count: 2) {
                            beginRename(summary.name)
                        }
                    renameButton(summary.name)
                    if summary.name == model.activeProfile {
                        BadgeChip(
                            label: L(
                                "profiles.badge.active",
                                "active"
                            )
                        )
                    }
                    if summary.isDefault {
                        BadgeChip(
                            label: L(
                                "profiles.badge.default",
                                "default"
                            )
                        )
                    }
                }
                monitorChips(summary)
            }
            Spacer()
            if !summary.isDefault {
                makeDefaultLink(summary.name)
            }
            // Load / Delete both end in `reload()`, which
            // re-seeds from disk and clears the dirty flag, so
            // both drop staged edits — gated like the edit-
            // target menu (#515).
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
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help(
                summary.matchesLive
                    ? ""
                    : L(
                        "profiles.other_monitors.help",
                        "Saved for other monitors — loads "
                            + "with unsaved-changes state."
                    )
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
                ) { model.deleteProfile(named: summary.name) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .iconButtonAffordance(
                L("profiles.delete.help", "Delete profile")
            )
        }
    }

    /// "make default" is a quiet inline link — underlined
    /// lowercase text rather than a button; hover lifts the
    /// color and shows the pointing-hand cursor.
    private func makeDefaultLink(
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

    /// Each covered monitor combination as one chip row, so
    /// screen→profile membership is visible at a glance.
    private func monitorChips(
        _ summary: ProfileSummary
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(
                Array(summary.sets.enumerated()),
                id: \.offset
            ) { _, set in
                WrapChips(set) { monitor in
                    // Display names, not raw fingerprints
                    // (#68 §3.15) — the diagnostic ID demotes
                    // to a tooltip and stays copyable under
                    // Monitors ▸ Advanced. Unknown hardware
                    // falls back to the raw string.
                    Text(model.monitorName(monitor))
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(.quaternary.opacity(0.4))
                        )
                        .help(monitor)
                }
            }
        }
    }
}
