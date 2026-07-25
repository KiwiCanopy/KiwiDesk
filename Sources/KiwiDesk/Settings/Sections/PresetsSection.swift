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
            Text(startHereText)
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

    /// Hoisted out of the builder (§5 shallow-body guardrail:
    /// concatenated literals inside one body expression).
    private var startHereText: String {
        L(
            "presets.start_here",
            "Start here — apply a preset for your "
                + "setup, then adjust anything from "
                + "any tab."
        )
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

    /// Zero-profile spotlight (ui-designer 2026-07-19): ONE
    /// Apply goes accent-prominent until the first profile
    /// exists — the appliable count's Standard preset, so the
    /// spotlight stays a single primary (review 2026-07-19:
    /// prominence on every appliable preset put three accent
    /// buttons in one field, four with the footer's).
    @ViewBuilder private func applyButton(
        _ layout: StandardLayout
    ) -> some View {
        // Two independent reasons Apply can be unavailable, so
        // the help has to say WHICH one (#518).
        let editing = model.editingStoredProfile
        let appliable =
            model.displays.count == layout.screenCount
            && !editing
        // Apply materializes a profile and reloads, so it
        // drops staged edits like the profile actions (#515).
        let button = Button(L("presets.apply", "Apply")) {
            model.discardingEdits(
                message: L(
                    "discard.apply_preset.message",
                    "Applying a preset replaces the edits you "
                        + "haven't saved."
                ),
                confirmLabel: L(
                    "discard.apply_preset.confirm",
                    "Discard & apply"
                )
            ) { model.applyStandardPreset(layout) }
        }
        .controlSize(.large)
        .disabled(!appliable)
        .help(applyHelp(layout, editing: editing))
        if appliable, layout.isStandard,
            model.profileSummaries.isEmpty
        {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    /// Greyed, never hidden (#171) — with the reason, because
    /// "why is Apply dead" has two different answers and the
    /// stored-profile one contradicts what the user just read
    /// in the header.
    private func applyHelp(
        _ layout: StandardLayout,
        editing: Bool
    ) -> String {
        if editing {
            return L(
                "presets.editing_stored",
                "Applying a preset switches your live layout, "
                    + "which editing a saved profile never does. "
                    + "Switch to Live to apply one."
            )
        }
        if model.displays.count != layout.screenCount {
            return L(
                "presets.needs_screens",
                "Needs %1$d connected screen(s).",
                layout.screenCount
            )
        }
        return ""
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
