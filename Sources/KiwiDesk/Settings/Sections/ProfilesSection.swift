import KiwiDeskCore
import SwiftUI

/// Whole App ▸ Profiles (#36/#53/#68 §3.2): the built-in
/// per-count layouts (applyable Presets), the saved-profiles
/// list grouped by screen count, and the native-Space bindings
/// — "which profile applies where/when" in one place.
struct ProfilesSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                presetSection
                profileSection
                // "Which profile applies where/when" lives
                // together (#68 §3.2): native-Space bindings
                // are global — only offered in live editing.
                if !model.editingStoredProfile {
                    NativeSpacesSection(model: model)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Built-in presets (#53)

    private var presetSection: some View {
        SettingsSection("Presets") {
            Text(
                "Built-in layouts per screen count. Apply "
                    + "loads one and saves it as a real, "
                    + "editable profile — only available when "
                    + "the connected screen count matches."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            ForEach(presetCounts, id: \.self) { count in
                countHeader(count)
                ForEach(
                    StandardProfiles.layouts(for: count),
                    id: \.name
                ) { layout in
                    presetRow(layout)
                }
            }
        }
    }

    private var presetCounts: [Int] {
        Array(
            Set(StandardProfiles.all.map(\.screenCount))
        ).sorted()
    }

    private func countHeader(_ count: Int) -> some View {
        Text(
            count == 1
                ? "1 screen" : "\(count) screens"
        )
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    private func presetRow(
        _ layout: StandardLayout
    ) -> some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(layout.name).font(.headline)
                    if layout.isStandard {
                        BadgeChip(label: "standard")
                    }
                }
                Text(layout.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PresetThumbnail(layout: layout)
            }
            Spacer()
            Button("Apply") {
                model.applyStandardPreset(layout)
            }
            .disabled(
                model.displays.count != layout.screenCount
            )
            .help(
                model.displays.count == layout.screenCount
                    ? ""
                    : "Needs \(layout.screenCount) connected "
                        + "screen(s)."
            )
        }
        .padding(.vertical, 2)
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

/// A mini layout diagram (#68 §3.15): one tile per space, each
/// carrying its mode's glyph (§6.3), so choosing a preset stops
/// requiring prose alone.
struct PresetThumbnail: View {
    let layout: StandardLayout

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...layout.spaceCount, id: \.self) { n in
                let mode =
                    layout.spaceModes[SpaceID(n)] ?? .bsp
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 24, height: 18)
                    .overlay {
                        Image(systemName: mode.glyph)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .help("Space \(n): \(mode.displayName)")
            }
        }
        .padding(.top, 1)
    }
}
