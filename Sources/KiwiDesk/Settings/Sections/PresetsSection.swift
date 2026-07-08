import KiwiDeskCore
import SwiftUI

/// Whole App ▸ Profiles ▸ Presets (#53): the built-in
/// per-screen-count layouts. Presets are a bootstrap tool, so
/// once the user has saved profiles of their own, this section
/// lists below them instead of on top (the full list either
/// way — no disclosure folding).
struct PresetsSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection("Presets") {
            rows
        }
    }

    @ViewBuilder private var rows: some View {
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
            .controlSize(.large)
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
