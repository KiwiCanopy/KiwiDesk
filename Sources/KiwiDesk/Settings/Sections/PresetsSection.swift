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
        SettingsSection(L("presets.title", "Presets")) {
            rows
        }
    }

    @ViewBuilder private var rows: some View {
        if model.profileSummaries.isEmpty {
            // Zero-profile spotlight (ui-designer 2026-07-19):
            // the lead-in labels the bootstrap the section
            // already is; state-driven, gone once any profile
            // exists.
            Text(
                L(
                    "presets.start_here",
                    "Start here — apply a preset for your "
                        + "setup, then adjust anything from "
                        + "any tab."
                )
            )
            .font(.callout)
            .fontWeight(.medium)
        }
        Text(rowsCaption)
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

    private var rowsCaption: String {
        L(
            "presets.caption",
            "Built-in layouts per screen count. Apply "
                + "loads one and saves it as a real, "
                + "editable profile — only available when "
                + "the connected screen count matches."
        )
    }

    private var presetCounts: [Int] {
        Array(
            Set(StandardProfiles.all.map(\.screenCount))
        ).sorted()
    }

    private func countHeader(_ count: Int) -> some View {
        Text(
            count == 1
                ? L("profiles.screens.one", "1 screen")
                : L(
                    "profiles.screens.many",
                    "%1$d screens",
                    count
                )
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
                    Text(layout.displayName).font(.headline)
                    if layout.isStandard {
                        BadgeChip(
                            label: L(
                                "presets.standard_badge",
                                "standard"
                            )
                        )
                    }
                }
                Text(layout.displaySummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PresetThumbnail(layout: layout)
            }
            Spacer()
            applyButton(layout)
        }
        .padding(.vertical, 2)
    }

    /// Zero-profile spotlight (ui-designer 2026-07-19): the
    /// appliable presets' Apply goes accent-prominent — the
    /// footer's one-accent-action vocabulary — until the first
    /// profile exists; then everything reverts to `.bordered`.
    @ViewBuilder private func applyButton(
        _ layout: StandardLayout
    ) -> some View {
        let appliable =
            model.displays.count == layout.screenCount
        let button = Button(L("presets.apply", "Apply")) {
            model.applyStandardPreset(layout)
        }
        .controlSize(.large)
        .disabled(!appliable)
        .help(
            appliable
                ? ""
                : L(
                    "presets.needs_screens",
                    "Needs %1$d connected screen(s).",
                    layout.screenCount
                )
        )
        if appliable, model.profileSummaries.isEmpty {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
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
                    .help(
                        L(
                            "presets.space_label",
                            "Space %1$d: %2$@",
                            n,
                            mode.displayName
                        )
                    )
            }
        }
        .padding(.top, 1)
    }
}
