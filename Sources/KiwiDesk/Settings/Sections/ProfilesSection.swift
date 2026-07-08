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
        if !model.editingStoredProfile {
            NativeSpacesSection(model: model)
        }
    }

    // MARK: - Saved profiles (#36)

    private var profileSection: some View {
        SettingsSection("Saved profiles") {
            if model.profileSummaries.isEmpty {
                Text(
                    "No profiles saved yet — the built-in "
                        + "Standard resolves until you save "
                        + "one."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            ForEach(profileCounts, id: \.self) { count in
                countGroupHeader(count)
                ForEach(summaries(for: count)) { summary in
                    profileRow(summary)
                }
            }
        }
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
            Text(count == 1 ? "1 screen" : "\(count) screens")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            if count == model.displays.count {
                BadgeChip(label: "connected")
            }
            if model.duplicateDefaultCounts.contains(count) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
                    .help(
                        "Several profiles of this count are "
                            + "marked default; the "
                            + "alphabetically first wins."
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
                    if summary.name == model.activeProfile {
                        BadgeChip(label: "active")
                    }
                    if summary.isDefault {
                        BadgeChip(label: "default")
                    }
                }
                monitorChips(summary)
            }
            Spacer()
            if !summary.isDefault {
                Button("Make default") {
                    model.makeDefault(named: summary.name)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            Button("Load") {
                model.loadProfile(named: summary.name)
            }
            .help(
                summary.matchesLive
                    ? ""
                    : "Saved for other monitors — loads with "
                        + "unsaved-changes state."
            )
            Button {
                model.deleteProfile(named: summary.name)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete profile")
        }
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
                                .fill(.quaternary.opacity(0.6))
                        )
                        .help(monitor)
                }
            }
        }
    }
}
