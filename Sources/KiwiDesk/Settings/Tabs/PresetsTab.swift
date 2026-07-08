import KiwiDeskCore
import SwiftUI

/// Tab 1 — Presets & Profiles (#36/#53): the built-in per-count
/// layouts (applyable Presets) and the saved-profiles list,
/// grouped by screen count with the monitor sets visible.
struct PresetsTab: View {
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
                        badge("standard")
                    }
                }
                Text(layout.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                badge("connected")
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
                        badge("active")
                    }
                    if summary.isDefault {
                        badge("default")
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
                    Text(monitor)
                        .font(
                            .system(
                                size: 10,
                                design: .monospaced
                            )
                        )
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(.quaternary.opacity(0.6))
                        )
                }
            }
        }
    }

    private func badge(_ label: String) -> some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(.tint.opacity(0.2))
            .clipShape(Capsule())
    }
}
